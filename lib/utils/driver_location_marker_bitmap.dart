import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Builds a Uber-style puck: ring + inner disc + directional chevron (points north;
/// rotate the [Marker] with [Marker.rotation] for heading).
Future<BitmapDescriptor> buildDriverLocationMarkerBitmap({
  required bool darkVariant,
}) async {
  /// Output pixel size ~75% of the original puck so it reads smaller on the map.
  const double size = 96;

  /// Reference design size (maintains proportional stroke, radii, chevron).
  const double base = 128;
  final scale = size / base;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);

  final Color outer = darkVariant
      ? Colors.white.withValues(alpha: 0.95)
      : const Color(0xFF6C4FE0);
  final Color innerFill = darkVariant ? Colors.black : Colors.white;
  final Color arrow = darkVariant ? Colors.white : const Color(0xFF6C4FE0);

  // Outer ring / stroke
  final outerPaint = Paint()
    ..color = outer
    ..style = PaintingStyle.stroke
    ..strokeWidth = (darkVariant ? 5 : 6) * scale;
  canvas.drawCircle(center, 38 * scale, outerPaint);

  // Inner puck
  canvas.drawCircle(center, 30 * scale, Paint()..color = innerFill);

  // Chevron (navigation arrow pointing up)
  final r = 16.0 * scale;
  final path = Path()
    ..moveTo(center.dx, center.dy - r * 1.05)
    ..lineTo(center.dx - r * 0.9, center.dy + r * 0.65)
    ..lineTo(center.dx + r * 0.9, center.dy + r * 0.65)
    ..close();
  canvas.drawPath(path, Paint()..color = arrow);

  final picture = recorder.endRecording();
  final img = await picture.toImage(size.toInt(), size.toInt());
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.bytes(bd!.buffer.asUint8List());
}
