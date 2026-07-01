import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';

class WorkoutDetailMap extends StatefulWidget {
  final Workout workout;
  final ValueNotifier<LatLng?> trackingPinPositionNotifier;
  final double? height;

  const WorkoutDetailMap({
    super.key,
    required this.workout,
    required this.trackingPinPositionNotifier,
    this.height,
  });

  @override
  State<WorkoutDetailMap> createState() => _WorkoutDetailMapState();
}

class _WorkoutDetailMapState extends State<WorkoutDetailMap> {
  BitmapDescriptor? _trackingIcon;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _parseRoutePoints();
    _createTrackingPinIcon();
    widget.trackingPinPositionNotifier.addListener(_onPinChanged);
  }

  @override
  void dispose() {
    widget.trackingPinPositionNotifier.removeListener(_onPinChanged);
    super.dispose();
  }

  void _parseRoutePoints() {
    if (widget.workout.polyline != null && widget.workout.polyline!.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(widget.workout.polyline!);
        _routePoints = decoded.map((p) => LatLng(
          (p[0] as num).toDouble(),
          (p[1] as num).toDouble(),
        )).toList();
      } catch (e) {
        // ignore
      }
    }
  }

  Future<void> _createTrackingPinIcon() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paintBorder = Paint()..color = AppTheme.accent; // Kora Accent Color
    final Paint paintWhite = Paint()..color = Colors.white;

    canvas.drawCircle(const Offset(24, 24), 16, paintBorder);
    canvas.drawCircle(const Offset(24, 24), 10, paintWhite);

    final ui.Image image = await pictureRecorder.endRecording().toImage(48, 48);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null && mounted) {
      setState(() {
        _trackingIcon = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
      });
    }
  }

  void _onPinChanged() {
    if (mounted) {
      setState(() {});
      // Smoothly animate map camera to follow the pin if needed, but standard is just updating marker position
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_routePoints.isEmpty) return const SizedBox.shrink();

    final activePin = widget.trackingPinPositionNotifier.value;

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 1),
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeNotifier,
        builder: (context, _, __) {
          return GoogleMap(
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            initialCameraPosition: CameraPosition(
              target: _routePoints[_routePoints.length ~/ 2],
              zoom: 14.0,
            ),
            style: AppTheme.isDarkMode ? '''[
              {"elementType":"geometry","stylers":[{"color":"#212121"}]},
              {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
              {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
              {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
              {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
              {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
              {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
              {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
              {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]}
            ]''' : null,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            mapToolbarEnabled: false,
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: _routePoints,
                color: AppTheme.accent,
                width: 5,
                jointType: JointType.round,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            },
            markers: {
              Marker(
                markerId: const MarkerId('start'),
                position: _routePoints.first,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
              if (_routePoints.length > 1)
                Marker(
                  markerId: const MarkerId('end'),
                  position: _routePoints.last,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ),
              if (activePin != null)
                Marker(
                  markerId: const MarkerId('tracking'),
                  position: activePin,
                  icon: _trackingIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                  anchor: const Offset(0.5, 0.5),
                  zIndex: 10.0,
                ),
            },
            onMapCreated: (controller) {
              Future.delayed(const Duration(milliseconds: 150), () {
                double minLat = _routePoints.first.latitude;
                double maxLat = _routePoints.first.latitude;
                double minLng = _routePoints.first.longitude;
                double maxLng = _routePoints.first.longitude;
                for (final p in _routePoints) {
                  if (p.latitude < minLat) minLat = p.latitude;
                  if (p.latitude > maxLat) maxLat = p.latitude;
                  if (p.longitude < minLng) minLng = p.longitude;
                  if (p.longitude > maxLng) maxLng = p.longitude;
                }
                controller.animateCamera(
                  CameraUpdate.newLatLngBounds(
                    LatLngBounds(
                      southwest: LatLng(minLat, minLng),
                      northeast: LatLng(maxLat, maxLng),
                    ),
                    40.0,
                  ),
                );
              });
            },
          );
        }
      ),
    );
  }
}
