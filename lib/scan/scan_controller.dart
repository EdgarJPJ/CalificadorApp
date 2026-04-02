import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'scan_models.dart';

class ScanController extends ChangeNotifier {
  ScanController({
    NormalizedRect guideRect = const NormalizedRect(
      left: 0.12,
      top: 0.16,
      right: 0.88,
      bottom: 0.84,
    ),
    Duration stabilityWindow = const Duration(milliseconds: 500),
  }) : _guideRect = guideRect,
       _stabilityWindow = stabilityWindow,
       _state = ScanViewState(
         status: ScanStatus.notDetected,
         guideRect: guideRect,
         markers: const [],
         candidates: const [],
         message: 'No detectado',
       );

  final NormalizedRect _guideRect;
  final Duration _stabilityWindow;
  ScanViewState _state;
  DateTime? _stableSince;
  List<Offset>? _lastStableMarkers;

  ScanViewState get state => _state;

  bool get isReadyToCapture => _state.status == ScanStatus.ready;
  NormalizedRect get guideRect => _guideRect;

  void updateDetection(MarkerDetectionResult result) {
    if (_state.status == ScanStatus.capturing ||
        _state.status == ScanStatus.uploading) {
      return;
    }

    if (!result.hasExactMarkers) {
      _stableSince = null;
      _lastStableMarkers = null;
      _setState(
        _state.copyWith(
          status: ScanStatus.notDetected,
          candidates: result.candidates,
          markers: result.markers,
          message: 'No detectado',
        ),
      );
      return;
    }

    if (!result.formsRectangle || !result.isInsideGuide) {
      _stableSince = null;
      _lastStableMarkers = null;
      _setState(
        _state.copyWith(
          status: ScanStatus.aligning,
          candidates: result.candidates,
          markers: result.markers,
          message: 'Alineando',
        ),
      );
      return;
    }

    final now = DateTime.now();
    final sameAsPrevious =
        _lastStableMarkers != null &&
        _averageDistance(_lastStableMarkers!, result.markers) < 0.025;

    if (!sameAsPrevious) {
      _stableSince = now;
      _lastStableMarkers = List<Offset>.from(result.markers);
      _setState(
        _state.copyWith(
          status: ScanStatus.aligning,
          candidates: result.candidates,
          markers: result.markers,
          message: 'Alineando',
        ),
      );
      return;
    }

    if (_stableSince != null &&
        now.difference(_stableSince!) >= _stabilityWindow) {
      _setState(
        _state.copyWith(
          status: ScanStatus.ready,
          candidates: result.candidates,
          markers: result.markers,
          message: 'Listo',
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        status: ScanStatus.aligning,
        candidates: result.candidates,
        markers: result.markers,
        message: 'Alineando',
      ),
    );
  }

  void markCapturing() {
    _setState(
      _state.copyWith(status: ScanStatus.capturing, message: 'Capturando...'),
    );
  }

  void markUploading() {
    _setState(
      _state.copyWith(
        status: ScanStatus.uploading,
        message: 'Enviando al servidor...',
      ),
    );
  }

  void markError(String message) {
    _stableSince = null;
    _lastStableMarkers = null;
    _setState(_state.copyWith(status: ScanStatus.error, message: message));
  }

  void reset() {
    _stableSince = null;
    _lastStableMarkers = null;
    _setState(
      ScanViewState(
        status: ScanStatus.notDetected,
        guideRect: _guideRect,
        markers: const [],
        candidates: const [],
        message: 'No detectado',
      ),
    );
  }

  void _setState(ScanViewState next) {
    _state = next;
    notifyListeners();
  }

  double _averageDistance(List<Offset> a, List<Offset> b) {
    if (a.length != b.length || a.isEmpty) {
      return double.infinity;
    }

    var total = 0.0;
    for (var i = 0; i < a.length; i++) {
      total += (a[i] - b[i]).distance;
    }
    return total / a.length;
  }
}
