import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'scan_models.dart';

class MarkerDetector {
  const MarkerDetector({
    this.guideRect = const NormalizedRect(
      left: 0.12,
      top: 0.16,
      right: 0.88,
      bottom: 0.84,
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

  final longestSide = math.max(width, height);
  final sampleStep = math.max(2, longestSide ~/ 180);
  final reducedWidth = math.max(1, width ~/ sampleStep);
  final reducedHeight = math.max(1, height ~/ sampleStep);

  final luminance = List<int>.filled(reducedWidth * reducedHeight, 0);
  var sum = 0;
  for (var y = 0; y < reducedHeight; y++) {
    final sourceY = math.min(height - 1, y * sampleStep);
    for (var x = 0; x < reducedWidth; x++) {
      final sourceX = math.min(width - 1, x * sampleStep);
      final value = bytes[(sourceY * bytesPerRow) + sourceX];
      final index = (y * reducedWidth) + x;
      luminance[index] = value;
      sum += value;
    }
  }

  final mean = sum / luminance.length;
  final threshold = math.min(90.0, mean * 0.58).round();
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
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1],
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
      final center = Offset(
        (sumX / count + 0.5) / reducedWidth,
        (sumY / count + 0.5) / reducedHeight,
      );

      final insideLooseGuide =
          center.dx >= guideRect.left - 0.08 &&
          center.dx <= guideRect.right + 0.08 &&
          center.dy >= guideRect.top - 0.08 &&
          center.dy <= guideRect.bottom + 0.08;

      if (count >= 4 &&
          aspectRatio >= 0.55 &&
          aspectRatio <= 1.45 &&
          fillRatio >= 0.35 &&
          areaRatio >= 0.00008 &&
          areaRatio <= 0.025 &&
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

    if (bestIndex == -1 || bestDistance > 0.18) {
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

  return widthRatio >= 0.75 &&
      widthRatio <= 1.25 &&
      heightRatio >= 0.75 &&
      heightRatio <= 1.25 &&
      diagonalRatio >= 0.75 &&
      diagonalRatio <= 1.25 &&
      topSlope <= guideRect.height * 0.14 &&
      bottomSlope <= guideRect.height * 0.14 &&
      leftSlope <= guideRect.width * 0.14 &&
      rightSlope <= guideRect.width * 0.14 &&
      topWidth >= guideRect.width * 0.55 &&
      leftHeight >= guideRect.height * 0.55;
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
