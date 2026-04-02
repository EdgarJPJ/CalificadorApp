import 'package:flutter/material.dart';

import 'scan_models.dart';

class ScanOverlayPainter extends CustomPainter {
  const ScanOverlayPainter({required this.state});

  final ScanViewState state;

  @override
  void paint(Canvas canvas, Size size) {
    final guideRect = Rect.fromLTWH(
      state.guideRect.left * size.width,
      state.guideRect.top * size.height,
      state.guideRect.width * size.width,
      state.guideRect.height * size.height,
    );

    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.36);
    final clearPaint = Paint()..blendMode = BlendMode.clear;

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, backgroundPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(guideRect, const Radius.circular(28)),
      clearPaint,
    );
    canvas.restore();

    final statusColor = switch (state.status) {
      ScanStatus.ready => const Color(0xFF1DB954),
      ScanStatus.capturing || ScanStatus.uploading => const Color(0xFF1DB954),
      ScanStatus.error => const Color(0xFFE53935),
      ScanStatus.aligning => const Color(0xFFFFB300),
      ScanStatus.notDetected => const Color(0xFFE53935),
    };

    final framePaint = Paint()
      ..color = statusColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final cornerLength = 28.0;
    _drawCorner(
      canvas,
      guideRect.topLeft,
      cornerLength,
      framePaint,
      true,
      true,
    );
    _drawCorner(
      canvas,
      guideRect.topRight,
      cornerLength,
      framePaint,
      false,
      true,
    );
    _drawCorner(
      canvas,
      guideRect.bottomLeft,
      cornerLength,
      framePaint,
      true,
      false,
    );
    _drawCorner(
      canvas,
      guideRect.bottomRight,
      cornerLength,
      framePaint,
      false,
      false,
    );

    final candidatePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    for (final point in state.candidates) {
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        4,
        candidatePaint,
      );
    }

    final markerPaint = Paint()
      ..color = statusColor
      ..style = PaintingStyle.fill;
    for (final point in state.markers) {
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        7,
        markerPaint,
      );
    }
  }

  void _drawCorner(
    Canvas canvas,
    Offset corner,
    double length,
    Paint paint,
    bool left,
    bool top,
  ) {
    final horizontalEnd = Offset(
      corner.dx + (left ? length : -length),
      corner.dy,
    );
    final verticalEnd = Offset(corner.dx, corner.dy + (top ? length : -length));

    canvas.drawLine(corner, horizontalEnd, paint);
    canvas.drawLine(corner, verticalEnd, paint);
  }

  @override
  bool shouldRepaint(covariant ScanOverlayPainter oldDelegate) {
    return oldDelegate.state != state;
  }
}
