import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';

/// Painter class untuk merender rute lari tanpa lag di dalam List card.
/// Dipindahkan ke file ini agar bisa dipakai oleh widget lain (ActivityFeedCard, dll.)
class MiniRoutePainter extends CustomPainter {
  final List<LatLng> points;
  final Color? _routeColor;

  MiniRoutePainter(this.points, {Color? routeColor}) : _routeColor = routeColor;

  Color get routeColor => _routeColor ?? AppTheme.accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;

    if (latRange == 0 || lngRange == 0) return;

    const padding = 12.0;
    final usableWidth = size.width - (padding * 2);
    final usableHeight = size.height - (padding * 2);

    final scale = usableWidth / lngRange < usableHeight / latRange
        ? usableWidth / lngRange
        : usableHeight / latRange;

    final xOffset = padding + (usableWidth - lngRange * scale) / 2;
    final yOffset = padding + (usableHeight - latRange * scale) / 2;

    Offset getOffset(LatLng p) {
      final x = xOffset + (p.longitude - minLng) * scale;
      final y = size.height - (yOffset + (p.latitude - minLat) * scale);
      return Offset(x, y);
    }

    final paint = Paint()
      ..color = routeColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(getOffset(points.first).dx, getOffset(points.first).dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(getOffset(points[i]).dx, getOffset(points[i]).dy);
    }
    canvas.drawPath(path, paint);

    // Start dot (green)
    canvas.drawCircle(
      getOffset(points.first),
      5.5,
      Paint()..color = AppTheme.accent..style = PaintingStyle.fill,
    );

    // End dot (red)
    if (points.length > 1) {
      canvas.drawCircle(
        getOffset(points.last),
        5.5,
        Paint()..color = const Color(0xFFFF3400)..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MiniRoutePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.routeColor != routeColor;
  }

  /// Parses a raw polyline JSON string to a list of LatLng
  static List<LatLng> parsePolyline(String polylineStr) {
    try {
      final List<dynamic> decoded = jsonDecode(polylineStr);
      return decoded.map((p) => LatLng(
        (p[0] as num).toDouble(),
        (p[1] as num).toDouble(),
      )).toList();
    } catch (_) {
      return [];
    }
  }
}
