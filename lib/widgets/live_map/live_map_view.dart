import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/live_location.dart';
import '../../models/union_council.dart';
import '../../theme/app_theme.dart';

/// Haversine great-circle distance in meters — used both by [LiveMapView]
/// internally and by callers (e.g. the legend counts on the Attendance
/// screen) that need to know if a location is inside its UC's geofence.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _bearingDegrees(LatLng from, LatLng to) {
  final lat1 = from.latitude * pi / 180;
  final lat2 = to.latitude * pi / 180;
  final dLng = (to.longitude - from.longitude) * pi / 180;
  final y = sin(dLng) * cos(lat2);
  final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

LatLng _lerpLatLng(LatLng a, LatLng b, double t) => LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);

class _ExitAlert {
  _ExitAlert({required this.name, required this.unionCouncil});
  final String name;
  final String? unionCouncil;
}

/// Renders a small colored dot bitmap (person glyph + optional heading wedge)
/// for use as a Google Maps marker icon — generated once per color/arrow
/// combination and cached, since regenerating a bitmap every animation frame
/// would be far too expensive.
Future<BitmapDescriptor> _buildDotIcon({required Color color, required bool withArrow}) async {
  const size = 84.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size + (withArrow ? 16 : 0)));
  final center = Offset(size / 2, size / 2 + (withArrow ? 16 : 0));

  if (withArrow) {
    final path = Path()
      ..moveTo(center.dx, 0)
      ..lineTo(center.dx - 9, 20)
      ..lineTo(center.dx + 9, 20)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6);
  }

  canvas.drawCircle(center.translate(0, 2), size / 2 - 6, Paint()
    ..color = Colors.black.withValues(alpha: 0.28)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  canvas.drawCircle(center, size / 2 - 4, Paint()..color = Colors.white);
  canvas.drawCircle(center, size / 2 - 8, Paint()..color = color);

  final iconStr = String.fromCharCode(Icons.person_rounded.codePoint);
  final textPainter = TextPainter(textDirection: TextDirection.ltr)
    ..text = TextSpan(
      text: iconStr,
      style: TextStyle(fontSize: size * 0.4, fontFamily: Icons.person_rounded.fontFamily, package: Icons.person_rounded.fontPackage, color: Colors.white),
    )
    ..layout();
  textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));

  final picture = recorder.endRecording();
  final heightPx = (size + (withArrow ? 16 : 0)).toInt();
  final image = await picture.toImage(size.toInt(), heightPx);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

/// A real Google Maps live-tracking view — secretary dots glide smoothly
/// between successive GPS pings instead of teleporting (a single shared
/// animation interpolates every marker's position each time new data
/// arrives), pulse with a true ground-distance ripple while live, rotate to
/// show heading once real movement is detected, and trigger a slide-down
/// alert the moment someone crosses out of their UC's geofence. UC
/// geofences are drawn as circles; a short in-memory trail traces each
/// secretary's recent path.
class LiveMapView extends StatefulWidget {
  const LiveMapView({super.key, required this.locations, required this.unionCouncils, required this.onTapLocation});

  final List<LiveLocation> locations;
  final List<UnionCouncil> unionCouncils;
  final ValueChanged<LiveLocation> onTapLocation;

  @override
  State<LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends State<LiveMapView> with TickerProviderStateMixin {
  GoogleMapController? _controller;
  late final AnimationController _moveController;
  late final AnimationController _pulseController;

  Map<int, LatLng> _renderedPositions = {};
  Map<int, LatLng> _animFrom = {};
  Map<int, LatLng> _animTo = {};
  final Map<int, double> _bearing = {};
  final Map<int, List<LatLng>> _trails = {};
  final Map<int, bool> _wasOutside = {};

  final Map<String, BitmapDescriptor> _icons = {};
  bool _iconsReady = false;

  bool _didInitialFit = false;
  int? _selectedSecretaryId;

  _ExitAlert? _alert;
  Timer? _alertHideTimer;

  static const _fallbackCenter = LatLng(30.3753, 69.3451); // Pakistan centroid

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _loadIcons();
    _ingestLocations(initial: true);
  }

  Future<void> _loadIcons() async {
    final entries = await Future.wait([
      _buildDotIcon(color: AppColors.primary500, withArrow: false),
      _buildDotIcon(color: AppColors.primary500, withArrow: true),
      _buildDotIcon(color: AppColors.danger, withArrow: false),
      _buildDotIcon(color: AppColors.danger, withArrow: true),
      _buildDotIcon(color: AppColors.inkFaint, withArrow: false),
    ]);
    if (!mounted) return;
    setState(() {
      _icons['primary_plain'] = entries[0];
      _icons['primary_arrow'] = entries[1];
      _icons['danger_plain'] = entries[2];
      _icons['danger_arrow'] = entries[3];
      _icons['stale_plain'] = entries[4];
      _iconsReady = true;
    });
  }

  @override
  void didUpdateWidget(covariant LiveMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.locations, widget.locations)) {
      _ingestLocations();
    }
  }

  @override
  void dispose() {
    _moveController.dispose();
    _pulseController.dispose();
    _alertHideTimer?.cancel();
    super.dispose();
  }

  UnionCouncil? _ucFor(LiveLocation loc) {
    for (final uc in widget.unionCouncils) {
      if (uc.id == loc.unionCouncilId) return uc;
    }
    return null;
  }

  /// null when the UC has no geofence configured (so status is unknown).
  bool? _insideGeofence(LiveLocation loc) {
    final uc = _ucFor(loc);
    if (uc == null || !uc.hasGeofence) return null;
    return distanceMeters(loc.lat, loc.lng, uc.lat!, uc.lng!) <= uc.geofenceRadius;
  }

  void _ingestLocations({bool initial = false}) {
    final newFrom = <int, LatLng>{};
    final newTo = <int, LatLng>{};

    for (final loc in widget.locations) {
      final target = LatLng(loc.lat, loc.lng);
      final prev = _renderedPositions[loc.secretaryId];
      newFrom[loc.secretaryId] = prev ?? target;
      newTo[loc.secretaryId] = target;

      if (prev != null && distanceMeters(prev.latitude, prev.longitude, target.latitude, target.longitude) > 3) {
        _bearing[loc.secretaryId] = _bearingDegrees(prev, target);
      }

      final trail = _trails.putIfAbsent(loc.secretaryId, () => []);
      if (trail.isEmpty || trail.last != target) {
        trail.add(target);
        if (trail.length > 10) trail.removeAt(0);
      }

      final outsideNow = loc.fresh && _insideGeofence(loc) == false;
      final wasOutside = _wasOutside[loc.secretaryId] ?? false;
      if (outsideNow && !wasOutside && !initial) _showExitAlert(loc);
      _wasOutside[loc.secretaryId] = outsideNow;
    }

    _animFrom = newFrom;
    _animTo = newTo;
    _renderedPositions = newTo;

    if (initial) {
      _moveController.value = 1;
    } else {
      _moveController.forward(from: 0);
    }
  }

  void _showExitAlert(LiveLocation loc) {
    HapticFeedback.mediumImpact();
    setState(() => _alert = _ExitAlert(name: loc.name, unionCouncil: loc.unionCouncil));
    _alertHideTimer?.cancel();
    _alertHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _alert = null);
    });
  }

  BitmapDescriptor _iconFor(LiveLocation loc) {
    final base = !loc.fresh ? 'stale' : (_insideGeofence(loc) == false ? 'danger' : 'primary');
    final withArrow = loc.fresh && _bearing.containsKey(loc.secretaryId);
    return _icons['${base}_${withArrow ? 'arrow' : 'plain'}'] ?? _icons['stale_plain']!;
  }

  Color _dotColor(LiveLocation loc) {
    if (!loc.fresh) return AppColors.inkFaint;
    return _insideGeofence(loc) == false ? AppColors.danger : AppColors.primary500;
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  Future<void> _fitAll() async {
    final controller = _controller;
    if (controller == null || widget.locations.isEmpty) return;
    if (widget.locations.length == 1) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(widget.locations.first.lat, widget.locations.first.lng), 15));
      return;
    }
    final bounds = _boundsFor(widget.locations.map((l) => LatLng(l.lat, l.lng)).toList());
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  Future<void> _focusOn(LiveLocation loc) async {
    setState(() => _selectedSecretaryId = loc.secretaryId);
    await _controller?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(loc.lat, loc.lng), 15));
  }

  @override
  Widget build(BuildContext context) {
    if (!_iconsReady) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }

    if (!_didInitialFit && widget.locations.isNotEmpty) {
      _didInitialFit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
    }

    final initialCenter = widget.locations.isNotEmpty ? LatLng(widget.locations.first.lat, widget.locations.first.lng) : _fallbackCenter;
    final outsideNow = widget.locations.where((l) => l.fresh && _insideGeofence(l) == false).toList();

    return Stack(
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_moveController, _pulseController]),
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_moveController.value);
            final pulse = _pulseController.value;

            final markers = <Marker>{};
            final circles = <Circle>{};
            final polylines = <Polyline>{};

            for (final uc in widget.unionCouncils.where((u) => u.hasGeofence)) {
              circles.add(Circle(
                circleId: CircleId('geofence_${uc.id}'),
                center: LatLng(uc.lat!, uc.lng!),
                radius: uc.geofenceRadius.toDouble(),
                fillColor: AppColors.primary400.withValues(alpha: 0.08),
                strokeColor: AppColors.primary400.withValues(alpha: 0.45),
                strokeWidth: 1,
              ));
            }

            for (final entry in _trails.entries) {
              if (entry.value.length < 2) continue;
              final selected = entry.key == _selectedSecretaryId;
              polylines.add(Polyline(
                polylineId: PolylineId('trail_${entry.key}'),
                points: entry.value,
                width: selected ? 4 : 3,
                color: (selected ? AppColors.accent500 : AppColors.primary400).withValues(alpha: selected ? 0.85 : 0.5),
              ));
            }

            for (final loc in widget.locations) {
              final from = _animFrom[loc.secretaryId] ?? LatLng(loc.lat, loc.lng);
              final to = _animTo[loc.secretaryId] ?? LatLng(loc.lat, loc.lng);
              final point = _lerpLatLng(from, to, t);
              final selected = loc.secretaryId == _selectedSecretaryId;

              if (loc.fresh) {
                circles.add(Circle(
                  circleId: CircleId('pulse_${loc.secretaryId}'),
                  center: point,
                  radius: 14 + pulse * 45,
                  fillColor: _dotColor(loc).withValues(alpha: (1 - pulse) * 0.35),
                  strokeWidth: 0,
                ));
              }
              if (selected) {
                circles.add(Circle(
                  circleId: CircleId('selected_${loc.secretaryId}'),
                  center: point,
                  radius: 28,
                  fillColor: AppColors.accent500.withValues(alpha: 0.18),
                  strokeColor: AppColors.accent500.withValues(alpha: 0.6),
                  strokeWidth: 2,
                ));
              }

              markers.add(Marker(
                markerId: MarkerId('sec_${loc.secretaryId}'),
                position: point,
                icon: _iconFor(loc),
                rotation: _bearing[loc.secretaryId] ?? 0,
                anchor: const Offset(0.5, 0.62),
                onTap: () {
                  setState(() => _selectedSecretaryId = loc.secretaryId);
                  widget.onTapLocation(loc);
                },
              ));
            }

            return GoogleMap(
              initialCameraPosition: CameraPosition(target: initialCenter, zoom: 12),
              onMapCreated: (controller) => _controller = controller,
              markers: markers,
              circles: circles,
              polylines: polylines,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            );
          },
        ),
        if (outsideNow.isNotEmpty)
          Positioned(
            left: 10,
            right: 10,
            top: 10,
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: outsideNow.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final loc = outsideNow[i];
                  return GestureDetector(
                    onTap: () => _focusOn(loc),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)]),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(loc.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          left: 10,
          right: 10,
          top: _alert != null ? (outsideNow.isNotEmpty ? 52 : 10) : -70,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _alert != null ? 1 : 0,
            child: _alert == null
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_alert!.name} just left ${_alert!.unionCouncil ?? 'their Union Council'}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 14,
          child: FloatingActionButton.small(
            heroTag: 'live-map-fit',
            onPressed: () {
              setState(() => _selectedSecretaryId = null);
              _fitAll();
            },
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primary600,
            child: const Icon(Icons.center_focus_strong_rounded),
          ),
        ),
      ],
    );
  }
}
