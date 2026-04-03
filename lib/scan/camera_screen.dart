import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para usar compute()
import 'package:image/image.dart' as img; // Alias para no confundir con widget Image

import '../exam_models.dart';
import '../services/exam_upload_service.dart';
import 'marker_detector.dart';
import 'scan_controller.dart';
import 'scan_models.dart';
import 'scan_overlay_painter.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.materias});

  final List<Materia> materias;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final MarkerDetector _detector = const MarkerDetector();
  late final ScanController _scanController = ScanController(
    guideRect: _detector.guideRect,
  );

  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _isProcessingFrame = false;
  bool _isCapturing = false;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  CameraDescription? _selectedCamera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanController.dispose();
    final controller = _cameraController;
    _cameraController = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      unawaited(_stopImageStream());
      unawaited(controller.dispose());
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed && _selectedCamera != null) {
      unawaited(_initializeCamera(description: _selectedCamera));
    }
  }

  Future<void> _initializeCamera({CameraDescription? description}) async {
    setState(() {
      _isInitializing = true;
    });

    try {
      final cameras = await availableCameras();
      final selected =
          description ??
          cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );
      _selectedCamera = selected;

      final previous = _cameraController;
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await previous?.dispose();
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      _cameraController = controller;
      _scanController.reset();
      await _startImageStream();
    } on CameraException catch (error) {
      _scanController.markError(_cameraErrorMessage(error));
    } catch (error) {
      _scanController.markError('No se pudo inicializar la cámara: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _startImageStream() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages) {
      return;
    }

    await controller.startImageStream((image) {
      unawaited(_handleCameraImage(image));
    });
  }

  Future<void> _stopImageStream() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isStreamingImages) {
      return;
    }
    await controller.stopImageStream();
  }

  Future<void> _handleCameraImage(CameraImage image) async {
    if (!mounted || _isProcessingFrame || _isCapturing) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < const Duration(milliseconds: 300)) {
      return;
    }

    _lastFrameAt = now;
    _isProcessingFrame = true;

    try {
      final result = await _detector.detect(image);
      _scanController.updateDetection(result);
      if (_scanController.isReadyToCapture) {
        await _captureAndUpload();
      }
    } catch (error) {
      _scanController.markError('Falló la detección: $error');
    } finally {
      _isProcessingFrame = false;
    }
  }


  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
        return 'Permiso de cámara denegado.';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Habilita la cámara desde ajustes del sistema.';
      default:
        return 'Error de cámara: ${error.description ?? error.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear examen'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: AnimatedBuilder(
        animation: _scanController,
        builder: (context, _) {
          final state = _scanController.state;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (controller != null && controller.value.isInitialized)
                CameraPreview(controller)
              else
                const ColoredBox(color: Colors.black),
              CustomPaint(
                painter: ScanOverlayPainter(state: state),
                child: const SizedBox.expand(),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _StatusBanner(state: state),
                      const Spacer(),
                      Text(
                        'Alinea la hoja dentro del marco. La captura será automática.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (_isInitializing)
                const Center(child: CircularProgressIndicator()),
            ],
          );
        },
      ),
    );
  }
  Future<void> _captureAndUpload() async {
    final controller = _cameraController;
    if (_isCapturing || controller == null) {
      return;
    }

    _isCapturing = true;
    _scanController.markCapturing();

    try {
      await _stopImageStream();
      final photo = await controller.takePicture();

      if (!mounted) return;

      // 🔥 Rescatamos las coordenadas de los cuadros verdes detectados
      final currentMarkers = _scanController.state.markers;

      // 🔥 Mandamos a recortar la imagen en segundo plano
      final croppedPath = await compute(_cropImageTask, {
        'path': photo.path,
        'markers': currentMarkers.map((m) => [m.dx, m.dy]).toList(),
      });

      if (!mounted) return;

      // 🔥 Mostramos el diálogo, pero ahora con la imagen YA RECORTADA
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Vista previa del examen'),
            content: SizedBox(
              width: double.maxFinite,
              // Le pasamos la ruta de la imagen procesada
              child: Image.file(File(croppedPath), fit: BoxFit.contain),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Reintentar', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Enviar a Calificar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );

      if (confirm != true) {
        _isCapturing = false;
        _scanController.reset();
        await _startImageStream();
        return;
      }

      _scanController.markUploading();
      // 🔥 Enviamos al servidor únicamente el recorte limpio
      final results = await ExamUploadService.processExamImage(
        imagePath: croppedPath, 
        materias: widget.materias,
      );

      if (!mounted) return;

      Navigator.of(context).pop(results);
    } catch (error) {
      _isCapturing = false;
      _scanController.markError(error.toString());
      await _startImageStream();
    }
  }
}

// 🔥 FUNCIÓN QUE SE EJECUTA EN SEGUNDO PLANO PARA NO CONGELAR LA APP
Future<String> _cropImageTask(Map<String, dynamic> params) async {
  final path = params['path'] as String;
  final markersRaw = params['markers'] as List<List<double>>;

  if (markersRaw.length != 4) return path;

  // 1. Leemos la imagen original
  final bytes = File(path).readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) return path;

  // 2. Calculamos la "caja" (Bounding Box) que encierra los 4 puntos
  double minX = 1.0, maxX = 0.0, minY = 1.0, maxY = 0.0;
  for (final m in markersRaw) {
    if (m[0] < minX) minX = m[0];
    if (m[0] > maxX) maxX = m[0];
    if (m[1] < minY) minY = m[1];
    if (m[1] > maxY) maxY = m[1];
  }

  // 3. Agregamos un pequeño "colchón" (padding) del 3% para no cortar los bordes negros
  final padX = 0.01; 
  final padY = 0.01; 
  minX = math.max(0.0, minX - padX);
  maxX = math.min(1.0, maxX + padX);
  minY = math.max(0.0, minY - padY);
  maxY = math.min(1.0, maxY + padY);

  // 4. Convertimos a píxeles reales de la foto
  final cropX = (minX * image.width).toInt();
  final cropY = (minY * image.height).toInt();
  final cropW = ((maxX - minX) * image.width).toInt();
  final cropH = ((maxY - minY) * image.height).toInt();

  // 5. Recortamos
  final cropped = img.copyCrop(
    image,
    x: cropX,
    y: cropY,
    width: cropW,
    height: cropH,
  );

  // 6. Guardamos la nueva imagen en una ruta temporal
  final newPath = path.replaceAll('.jpg', '_cropped.jpg');
  File(newPath).writeAsBytesSync(img.encodeJpg(cropped, quality: 85));

  return newPath;
}
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state});

  final ScanViewState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state.status) {
      ScanStatus.ready => (Icons.check_circle, const Color(0xFF1DB954)),
      ScanStatus.capturing ||
      ScanStatus.uploading => (Icons.cloud_upload, const Color(0xFF1DB954)),
      ScanStatus.error => (Icons.error, const Color(0xFFE53935)),
      ScanStatus.aligning => (Icons.crop_free, const Color(0xFFFFB300)),
      ScanStatus.notDetected => (Icons.close, const Color(0xFFE53935)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(
            _labelForStatus(state.status),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              state.message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  String _labelForStatus(ScanStatus status) {
    return switch (status) {
      ScanStatus.notDetected => 'No detectado',
      ScanStatus.aligning => 'Alineando',
      ScanStatus.ready => 'Listo',
      ScanStatus.capturing => 'Capturando',
      ScanStatus.uploading => 'Enviando',
      ScanStatus.error => 'Error',
    };
  }
}
