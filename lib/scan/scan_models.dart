import 'dart:ui';

enum ScanStatus { notDetected, aligning, ready, capturing, uploading, error }

class NormalizedRect {
  const NormalizedRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  bool contains(Offset point) {
    return point.dx >= left &&
        point.dx <= right &&
        point.dy >= top &&
        point.dy <= bottom;
  }
}

class MarkerDetectionResult {
  const MarkerDetectionResult({
    required this.candidates,
    required this.markers,
    required this.guideRect,
    required this.hasExactMarkers,
    required this.formsRectangle,
    required this.isInsideGuide,
  });

  final List<Offset> candidates;
  final List<Offset> markers;
  final NormalizedRect guideRect;
  final bool hasExactMarkers;
  final bool formsRectangle;
  final bool isInsideGuide;

  bool get geometryReady => hasExactMarkers && formsRectangle && isInsideGuide;
}

class ScanViewState {
  const ScanViewState({
    required this.status,
    required this.guideRect,
    required this.markers,
    required this.candidates,
    required this.message,
  });

  final ScanStatus status;
  final NormalizedRect guideRect;
  final List<Offset> markers;
  final List<Offset> candidates;
  final String message;

  ScanViewState copyWith({
    ScanStatus? status,
    NormalizedRect? guideRect,
    List<Offset>? markers,
    List<Offset>? candidates,
    String? message,
  }) {
    return ScanViewState(
      status: status ?? this.status,
      guideRect: guideRect ?? this.guideRect,
      markers: markers ?? this.markers,
      candidates: candidates ?? this.candidates,
      message: message ?? this.message,
    );
  }
}
