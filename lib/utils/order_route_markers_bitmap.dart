import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Route purple matching Uber-style screenshots (#8E24AA).
const Color kOrderRoutePurple = Color(0xFF8E24AA);

/// White disc with stroked purple outer ring — pickup/start.
Future<BitmapDescriptor> pickupRouteMarkerBitmap() async {
  const size = 88.0;
  const scale = size / 112;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final c = Offset(size / 2, size / 2);
  canvas.drawCircle(
    c,
    28 * scale,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill,
  );
  canvas.drawCircle(
    c,
    28 * scale,
    Paint()
      ..color = kOrderRoutePurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * scale,
  );
  canvas.drawCircle(
    c,
    6 * scale,
    Paint()..color = kOrderRoutePurple,
  );
  final picture = recorder.endRecording();
  final img = await picture.toImage(size.ceil(), size.ceil());
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bd!.buffer.asUint8List());
}

/// Purple filled disc with thin white outer ring — destination/bullseye.
Future<BitmapDescriptor> destinationRouteMarkerBitmap() async {
  const size = 88.0;
  const scale = size / 112;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final c = Offset(size / 2, size / 2);
  canvas.drawCircle(
    c,
    31 * scale,
    Paint()
      ..color = kOrderRoutePurple
      ..style = PaintingStyle.fill,
  );
  canvas.drawCircle(
    c,
    31 * scale,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale,
  );
  canvas.drawCircle(
    c,
    10 * scale,
    Paint()..color = Colors.white,
  );
  final picture = recorder.endRecording();
  final img = await picture.toImage(size.ceil(), size.ceil());
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bd!.buffer.asUint8List());
}
