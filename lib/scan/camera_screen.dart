import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../exam_models.dart';
import '../services/exam_upload_service.dart';
import 'marker_detector.dart';
import 'scan_controller.dart';
import 'scan_models.dart';
import 'scan_overlay_painter.dart';

enum ScanUploadMode { uploadKey, gradeExam }

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.materias,
    required this.mode,
  });

  final List<Materia> materias;
  final ScanUploadMode mode;

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
      _scanController.markError('No se pudo inicializar la camara: $error');
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
      _scanController.markError('Fallo la deteccion: $error');
    } finally {
      _isProcessingFrame = false;
    }
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
        return 'Permiso de camara denegado.';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Habilita la camara desde ajustes del sistema.';
      default:
        return 'Error de camara: ${error.description ?? error.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_screenTitle),
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
                        'Alinea la hoja completa; la app recortara automaticamente al borde de los marcadores.',
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

      final currentMarkers = _scanController.state.markers;
      final croppedPath = await compute(_cropImageTask, {
        'path': photo.path,
        'markers': currentMarkers.map((m) => [m.dx, m.dy]).toList(),
      });

      if (!mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(_previewTitle),
            content: SizedBox(
              width: double.maxFinite,
              child: Image.file(File(croppedPath), fit: BoxFit.contain),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Reintentar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text(
                  _confirmLabel,
                  style: const TextStyle(color: Colors.white),
                ),
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
      final results = await _uploadImage(croppedPath);

      if (!mounted) return;

      Navigator.of(context).pop(results);
    } catch (error) {
      _isCapturing = false;
      _scanController.markError(error.toString());
      await _startImageStream();
    }
  }

  String get _screenTitle {
    return switch (widget.mode) {
      ScanUploadMode.uploadKey => 'Subir clave maestro',
      ScanUploadMode.gradeExam => 'Escanear alumno',
    };
  }

  String get _previewTitle {
    return switch (widget.mode) {
      ScanUploadMode.uploadKey => 'Vista previa de la clave',
      ScanUploadMode.gradeExam => 'Vista previa del examen',
    };
  }

  String get _confirmLabel {
    return switch (widget.mode) {
      ScanUploadMode.uploadKey => 'Enviar clave maestro',
      ScanUploadMode.gradeExam => 'Enviar a calificar',
    };
  }

  Future<Map<String, dynamic>> _uploadImage(String croppedPath) {
    return switch (widget.mode) {
      ScanUploadMode.uploadKey => ExamUploadService.uploadKey(
        imagePath: croppedPath,
        materias: widget.materias,
      ),
      ScanUploadMode.gradeExam => ExamUploadService.gradeExam(
        imagePath: croppedPath,
      ),
    };
  }
}

Future<String> _cropImageTask(Map<String, dynamic> params) async {
  final path = params['path'] as String;
  final markersRaw = (params['markers'] as List)
      .map(
        (entry) =>
            (entry as List).map((value) => (value as num).toDouble()).toList(),
      )
      .toList();

  if (markersRaw.length != 4) return path;

  final bytes = File(path).readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) return path;

  double minX = 1.0;
  double maxX = 0.0;
  double minY = 1.0;
  double maxY = 0.0;

  for (final marker in markersRaw) {
    minX = math.min(minX, marker[0]);
    maxX = math.max(maxX, marker[0]);
    minY = math.min(minY, marker[1]);
    maxY = math.max(maxY, marker[1]);
  }

  if ((maxX - minX) < 0.20 || (maxY - minY) < 0.20) {
    return path;
  }

  var cropRect = _safeExpandedCropRect(
    minX: minX,
    maxX: maxX,
    minY: minY,
    maxY: maxY,
    imageWidth: image.width,
    imageHeight: image.height,
    paddingX: 0.035,
    paddingY: 0.035,
  );

  if (!_hasSafeMarkerMargin(cropRect, minX, maxX, minY, maxY)) {
    cropRect = _safeExpandedCropRect(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      imageWidth: image.width,
      imageHeight: image.height,
      paddingX: 0.055,
      paddingY: 0.055,
    );
  }

  if (!cropRect.isValid) {
    return path;
  }

  final cropped = img.copyCrop(
    image,
    x: cropRect.x,
    y: cropRect.y,
    width: cropRect.width,
    height: cropRect.height,
  );

  final newPath = path.replaceAll('.jpg', '_cropped.jpg');
  File(newPath).writeAsBytesSync(img.encodeJpg(cropped, quality: 88));

  return newPath;
}

_CropRect _safeExpandedCropRect({
  required double minX,
  required double maxX,
  required double minY,
  required double maxY,
  required int imageWidth,
  required int imageHeight,
  required double paddingX,
  required double paddingY,
}) {
  final left = math.max(0.0, minX - paddingX);
  final right = math.min(1.0, maxX + paddingX);
  final top = math.max(0.0, minY - paddingY);
  final bottom = math.min(1.0, maxY + paddingY);

  final x = (left * imageWidth).floor().clamp(0, imageWidth - 1);
  final y = (top * imageHeight).floor().clamp(0, imageHeight - 1);
  final rightPx = (right * imageWidth).ceil().clamp(x + 1, imageWidth);
  final bottomPx = (bottom * imageHeight).ceil().clamp(y + 1, imageHeight);

  return _CropRect(
    x: x,
    y: y,
    width: rightPx - x,
    height: bottomPx - y,
    left: left,
    right: right,
    top: top,
    bottom: bottom,
  );
}

bool _hasSafeMarkerMargin(
  _CropRect cropRect,
  double markerMinX,
  double markerMaxX,
  double markerMinY,
  double markerMaxY,
) {
  if (!cropRect.isValid) return false;

  const minMargin = 0.02;
  final cropWidth = cropRect.right - cropRect.left;
  final cropHeight = cropRect.bottom - cropRect.top;
  if (cropWidth <= 0 || cropHeight <= 0) return false;

  final leftMargin = (markerMinX - cropRect.left) / cropWidth;
  final rightMargin = (cropRect.right - markerMaxX) / cropWidth;
  final topMargin = (markerMinY - cropRect.top) / cropHeight;
  final bottomMargin = (cropRect.bottom - markerMaxY) / cropHeight;

  return leftMargin >= minMargin &&
      rightMargin >= minMargin &&
      topMargin >= minMargin &&
      bottomMargin >= minMargin;
}

class _CropRect {
  const _CropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  final int x;
  final int y;
  final int width;
  final int height;
  final double left;
  final double right;
  final double top;
  final double bottom;

  bool get isValid => width > 10 && height > 10 && right > left && bottom > top;
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
