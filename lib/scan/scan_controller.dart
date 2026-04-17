import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'scan_models.dart';

class ScanController extends ChangeNotifier {
  ScanController({
    NormalizedRect guideRect = const NormalizedRect(
      left: 0.06,
      top: 0.18,
      right: 0.94,
      bottom: 0.84,
    ),
    Duration stabilityWindow = const Duration(milliseconds: 900),
    int stableFramesRequired = 3,
  }) : _guideRect = guideRect,
       _stabilityWindow = stabilityWindow,
       _stableFramesRequired = stableFramesRequired,
       _state = ScanViewState(
         status: ScanStatus.notDetected,
         guideRect: guideRect,
         markers: const [],
         candidates: const [],
         message: 'Alinea los 4 marcadores',
       );

  final NormalizedRect _guideRect;
  final Duration _stabilityWindow;
  final int _stableFramesRequired;
  ScanViewState _state;
  DateTime? _stableSince;
  List<Offset>? _lastStableMarkers;
  int _stableFrameCount = 0;

  ScanViewState get state => _state;

  bool get isReadyToCapture => _state.status == ScanStatus.ready;
  NormalizedRect get guideRect => _guideRect;

  void updateDetection(MarkerDetectionResult result) {
    if (_state.status == ScanStatus.capturing ||
        _state.status == ScanStatus.uploading) {
      return;
    }

    if (!result.hasExactMarkers) {
      _resetStability();
      _setState(
        _state.copyWith(
          status: ScanStatus.notDetected,
          candidates: result.candidates,
          markers: result.markers,
          message: 'Busca los 4 marcadores...',
        ),
      );
      return;
    }

    if (!result.formsRectangle || !result.isInsideGuide) {
      _resetStability();
      _setState(
        _state.copyWith(
          status: ScanStatus.aligning,
          candidates: result.candidates,
          markers: result.markers,
          message: 'Deja espacio alrededor de los marcadores',
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
      _stableFrameCount = 1;
      _setState(
        _state.copyWith(
          status: ScanStatus.aligning,
          candidates: result.candidates,
          markers: result.markers,
          message: 'Manten quieto...',
        ),
      );
      return;
    }

    _stableFrameCount++;

    if (_stableSince != null &&
        now.difference(_stableSince!) >= _stabilityWindow &&
        _stableFrameCount >= _stableFramesRequired) {
      _setState(
        _state.copyWith(
          status: ScanStatus.ready,
          candidates: result.candidates,
          markers: result.markers,
          message: 'Listo!',
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        status: ScanStatus.aligning,
        candidates: result.candidates,
        markers: result.markers,
        message: 'Manten quieto...',
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
    _resetStability();
    _setState(_state.copyWith(status: ScanStatus.error, message: message));
  }

  void reset() {
    _resetStability();
    _setState(
      ScanViewState(
        status: ScanStatus.notDetected,
        guideRect: _guideRect,
        markers: const [],
        candidates: const [],
        message: 'Alinea los 4 marcadores',
      ),
    );
  }

  void _resetStability() {
    _stableSince = null;
    _lastStableMarkers = null;
    _stableFrameCount = 0;
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
