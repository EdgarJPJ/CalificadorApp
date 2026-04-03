import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'scan_models.dart';

class MarkerDetector {
  const MarkerDetector({
    this.guideRect = const NormalizedRect(
      left: 0.08, // 🔥 Regresamos a tu ancho original (más angosto)
      top: 0.22, // 🔥 Mantenemos la nueva altura que quedó perfecta
      right: 0.92, // 🔥 Regresamos a tu ancho original
      bottom: 0.78, // 🔥 Mantenemos la nueva altura
    ),
  });

  final NormalizedRect guideRect;

  Future<MarkerDetectionResult> detect(CameraImage image) async {
    if (image.planes.isEmpty) {
      return MarkerDetectionResult(
        candidates: const [],
        markers: const [],
        guideRect: guideRect,
        hasExactMarkers: false,
        formsRectangle: false,
        isInsideGuide: false,
      );
    }

    final result = await compute<Map<String, Object?>, Map<String, Object?>>(
      _detectMarkersInIsolate,
      <String, Object?>{
        'bytes': image.planes.first.bytes,
        'width': image.width,
        'height': image.height,
        'bytesPerRow': image.planes.first.bytesPerRow,
        'guideLeft': guideRect.left,
        'guideTop': guideRect.top,
        'guideRight': guideRect.right,
        'guideBottom': guideRect.bottom,
      },
    );

    return MarkerDetectionResult(
      candidates: _offsetListFromRaw(result['candidates']),
      markers: _offsetListFromRaw(result['markers']),
      guideRect: guideRect,
      hasExactMarkers: result['hasExactMarkers']! as bool,
      formsRectangle: result['formsRectangle']! as bool,
      isInsideGuide: result['isInsideGuide']! as bool,
    );
  }

  static List<Offset> _offsetListFromRaw(Object? raw) {
    final list = raw! as List<Object?>;
    return list
        .map((entry) => entry! as List<Object?>)
        .map(
          (entry) => Offset(
            (entry[0]! as num).toDouble(),
            (entry[1]! as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }
}

Map<String, Object?> _detectMarkersInIsolate(Map<String, Object?> payload) {
  final bytes = payload['bytes']! as Uint8List;
  final width = payload['width']! as int;
  final height = payload['height']! as int;
  final bytesPerRow = payload['bytesPerRow']! as int;
  final guideRect = NormalizedRect(
    left: (payload['guideLeft']! as num).toDouble(),
    top: (payload['guideTop']! as num).toDouble(),
    right: (payload['guideRight']! as num).toDouble(),
    bottom: (payload['guideBottom']! as num).toDouble(),
  );

  // 🔥 MAGIA AQUÍ: Detectar si el sensor de la cámara está "acostado" (Landscape)
  // mientras el teléfono está "de pie" (Portrait).
  final isRotated = width > height;

  // Convertimos el marco guía de la pantalla a las coordenadas reales del sensor
  double sGuideLeft = guideRect.left;
  double sGuideRight = guideRect.right;
  double sGuideTop = guideRect.top;
  double sGuideBottom = guideRect.bottom;

  if (isRotated) {
    // Rotación de 90 grados en dirección a las manecillas del reloj (Estándar en Android)
    sGuideLeft = guideRect.top;
    sGuideRight = guideRect.bottom;
    sGuideTop = 1.0 - guideRect.right;
    sGuideBottom = 1.0 - guideRect.left;
  }

  final longestSide = math.max(width, height);
  final sampleStep = math.max(1, longestSide ~/ 320);
  final reducedWidth = math.max(1, width ~/ sampleStep);
  final reducedHeight = math.max(1, height ~/ sampleStep);

  final luminance = List<int>.filled(reducedWidth * reducedHeight, 0);
  
  final minGuideX = (sGuideLeft * reducedWidth).toInt();
  final maxGuideX = (sGuideRight * reducedWidth).toInt();
  final minGuideY = (sGuideTop * reducedHeight).toInt();
  final maxGuideY = (sGuideBottom * reducedHeight).toInt();

  var sum = 0;
  var sampleCount = 0;

  for (var y = 0; y < reducedHeight; y++) {
    final sourceY = math.min(height - 1, y * sampleStep);
    for (var x = 0; x < reducedWidth; x++) {
      final sourceX = math.min(width - 1, x * sampleStep);
      final value = bytes[(sourceY * bytesPerRow) + sourceX];
      final index = (y * reducedWidth) + x;
      luminance[index] = value;
      
      // Calculamos la luz solo dentro del marco para ignorar la mesa oscura
      if (x >= minGuideX && x <= maxGuideX && y >= minGuideY && y <= maxGuideY) {
        sum += value;
        sampleCount++;
      }
    }
  }

  final mean = sampleCount > 0 ? sum / sampleCount : 128.0;
  final threshold = math.min(150.0, mean * 0.75).round();
  
  final visited = Uint8List(reducedWidth * reducedHeight);
  final candidates = <_BlobCandidate>[];
  final queueX = List<int>.filled(reducedWidth * reducedHeight, 0);
  final queueY = List<int>.filled(reducedWidth * reducedHeight, 0);

  for (var y = 0; y < reducedHeight; y++) {
    for (var x = 0; x < reducedWidth; x++) {
      final startIndex = (y * reducedWidth) + x;
      if (visited[startIndex] == 1 || luminance[startIndex] > threshold) {
        continue;
      }

      var head = 0;
      var tail = 0;
      queueX[tail] = x;
      queueY[tail] = y;
      tail++;
      visited[startIndex] = 1;

      var count = 0;
      var minX = x;
      var maxX = x;
      var minY = y;
      var maxY = y;
      var sumX = 0.0;
      var sumY = 0.0;

      while (head < tail) {
        final currentX = queueX[head];
        final currentY = queueY[head];
        head++;
        count++;
        sumX += currentX;
        sumY += currentY;
        minX = math.min(minX, currentX);
        maxX = math.max(maxX, currentX);
        minY = math.min(minY, currentY);
        maxY = math.max(maxY, currentY);

        for (final delta in const <List<int>>[
          [-1, 0], [1, 0], [0, -1], [0, 1],
        ]) {
          final nextX = currentX + delta[0];
          final nextY = currentY + delta[1];
          if (nextX < 0 ||
              nextY < 0 ||
              nextX >= reducedWidth ||
              nextY >= reducedHeight) {
            continue;
          }

          final nextIndex = (nextY * reducedWidth) + nextX;
          if (visited[nextIndex] == 1 || luminance[nextIndex] > threshold) {
            continue;
          }

          visited[nextIndex] = 1;
          queueX[tail] = nextX;
          queueY[tail] = nextY;
          tail++;
        }
      }

      final boxWidth = maxX - minX + 1;
      final boxHeight = maxY - minY + 1;
      final aspectRatio = boxWidth / boxHeight;
      final boxArea = boxWidth * boxHeight;
      final fillRatio = count / boxArea;
      final areaRatio = boxArea / (reducedWidth * reducedHeight);
      
      double normX = (sumX / count + 0.5) / reducedWidth;
      double normY = (sumY / count + 0.5) / reducedHeight;

      // 🔥 AQUÍ DEVOLVEMOS LAS COORDENADAS A LA NORMALIDAD (PORTRAIT)
      double finalX = normX;
      double finalY = normY;
      
      if (isRotated) {
        finalX = 1.0 - normY;
        finalY = normX;
      }

      final center = Offset(finalX, finalY);

      final insideLooseGuide =
          center.dx >= guideRect.left - 0.08 &&
          center.dx <= guideRect.right + 0.08 &&
          center.dy >= guideRect.top - 0.08 &&
          center.dy <= guideRect.bottom + 0.08;

      // Expandimos la tolerancia geométrica (aspectRatio de 0.35 a 2.50) para que
      // no rechace los cuadros si la cámara los distorsiona un poco al inclinar el teléfono.
      if (count >= 4 &&
          aspectRatio >= 0.35 &&
          aspectRatio <= 2.50 && 
          fillRatio >= 0.35 &&
          areaRatio >= 0.00004 && 
          areaRatio <= 0.04 &&
          insideLooseGuide) {
        candidates.add(
          _BlobCandidate(center: center, count: count, fillRatio: fillRatio),
        );
      }
    }
  }

  candidates.sort((a, b) => b.score.compareTo(a.score));
  final candidatePoints = candidates
      .take(12)
      .map((candidate) => candidate.center)
      .toList(growable: false);
  final markers = _matchMarkersToCorners(candidatePoints, guideRect);
  final hasExactMarkers = markers.length == 4;
  final isInsideGuide = hasExactMarkers && markers.every(guideRect.contains);
  final formsRectangle =
      hasExactMarkers && _validateRectangle(markers, guideRect);

  return <String, Object?>{
    'candidates': candidatePoints
        .map((point) => <double>[point.dx, point.dy])
        .toList(growable: false),
    'markers': markers
        .map((point) => <double>[point.dx, point.dy])
        .toList(growable: false),
    'hasExactMarkers': hasExactMarkers,
    'formsRectangle': formsRectangle,
    'isInsideGuide': isInsideGuide,
  };
}

List<Offset> _matchMarkersToCorners(
  List<Offset> candidates,
  NormalizedRect guideRect,
) {
  if (candidates.length < 4) {
    return const [];
  }

  final expectedCorners = <Offset>[
    Offset(guideRect.left, guideRect.top),
    Offset(guideRect.right, guideRect.top),
    Offset(guideRect.left, guideRect.bottom),
    Offset(guideRect.right, guideRect.bottom),
  ];
  final used = <int>{};
  final markers = <Offset>[];

  for (final corner in expectedCorners) {
    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < candidates.length; i++) {
      if (used.contains(i)) {
        continue;
      }
      final distance = (candidates[i] - corner).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    // 🔥 CORRECCIÓN 3: Tolerancia de encuadre ampliada a 0.25
    if (bestIndex == -1 || bestDistance > 0.25) {
      return const [];
    }

    used.add(bestIndex);
    markers.add(candidates[bestIndex]);
  }

  return markers;
}

bool _validateRectangle(List<Offset> markers, NormalizedRect guideRect) {
  if (markers.length != 4) {
    return false;
  }

  final topLeft = markers[0];
  final topRight = markers[1];
  final bottomLeft = markers[2];
  final bottomRight = markers[3];

  final topWidth = (topRight - topLeft).distance;
  final bottomWidth = (bottomRight - bottomLeft).distance;
  final leftHeight = (bottomLeft - topLeft).distance;
  final rightHeight = (bottomRight - topRight).distance;
  final diagonalA = (bottomRight - topLeft).distance;
  final diagonalB = (bottomLeft - topRight).distance;

  final widthRatio = topWidth / math.max(bottomWidth, 0.0001);
  final heightRatio = leftHeight / math.max(rightHeight, 0.0001);
  final diagonalRatio = diagonalA / math.max(diagonalB, 0.0001);
  final topSlope = (topLeft.dy - topRight.dy).abs();
  final bottomSlope = (bottomLeft.dy - bottomRight.dy).abs();
  final leftSlope = (topLeft.dx - bottomLeft.dx).abs();
  final rightSlope = (topRight.dx - bottomRight.dx).abs();

  // 🔥 Ligeramente más tolerante a la distorsión del rectángulo
  return widthRatio >= 0.70 &&
      widthRatio <= 1.30 &&
      heightRatio >= 0.70 &&
      heightRatio <= 1.30 &&
      diagonalRatio >= 0.70 &&
      diagonalRatio <= 1.30 &&
      topSlope <= guideRect.height * 0.20 &&
      bottomSlope <= guideRect.height * 0.20 &&
      leftSlope <= guideRect.width * 0.20 &&
      rightSlope <= guideRect.width * 0.20 &&
      topWidth >= guideRect.width * 0.40 &&
      leftHeight >= guideRect.height * 0.40;
}

class _BlobCandidate {
  const _BlobCandidate({
    required this.center,
    required this.count,
    required this.fillRatio,
  });

  final Offset center;
  final int count;
  final double fillRatio;

  double get score => count * fillRatio;
}
