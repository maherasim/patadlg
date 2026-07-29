import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/attendance_record.dart';
import '../../services/attendance_service.dart';
import '../../services/biometric_service.dart';
import '../../services/camera_service.dart';
import '../../services/location_service.dart';
import '../../services/location_tracking_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/status_badge.dart';
import '../../utils/time_format.dart';

const _movementReasons = ['Field Visit', 'Official Meeting', 'Errand', 'Medical', 'Other'];

class SecAttendanceScreen extends StatefulWidget {
  const SecAttendanceScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<SecAttendanceScreen> createState() => _SecAttendanceScreenState();
}

class _SecAttendanceScreenState extends State<SecAttendanceScreen> {
  bool _loadingHistory = true;
  List<AttendanceRecord> _history = [];
  String? _loadError;

  bool _marking = false;
  String? _markingStep;
  String? _markError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _setUpBackgroundTracking();
  }

  // Also triggered right after login (see login_screen.dart) so tracking
  // starts even if the secretary never opens this screen — calling it again
  // here is a cheap, idempotent safety net.
  Future<void> _setUpBackgroundTracking() => LocationTrackingService.instance.ensureStartedForSecretary();

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _loadError = null;
    });
    try {
      final history = await AttendanceService.instance.myHistory();
      if (!mounted) return;
      setState(() {
        _history = history;
        _loadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = "Couldn't load your attendance history.";
        _loadingHistory = false;
      });
    }
  }

  AttendanceRecord? get _todayRecord {
    final today = DateTime.now();
    final todayStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    for (final record in _history) {
      if (record.attendanceDate == todayStr) return record;
    }
    return null;
  }

  Future<void> _markAttendance() async {
    setState(() {
      _marking = true;
      _markError = null;
      _markingStep = 'Confirming your identity…';
    });

    try {
      final biometricAvailable = await BiometricService.instance.isAvailable();
      var biometricConfirmed = false;
      if (biometricAvailable) {
        biometricConfirmed = await BiometricService.instance.authenticate();
        if (!biometricConfirmed) {
          setState(() {
            _marking = false;
            _markingStep = null;
            _markError = 'Identity check was cancelled. Try again to mark attendance.';
          });
          return;
        }
      }

      setState(() => _markingStep = 'Getting your location…');
      final location = await LocationService.instance.getCurrentPosition();

      setState(() => _markingStep = 'Opening camera for your selfie…');
      final photo = await CameraService.instance.captureSelfie();
      if (photo == null) {
        setState(() {
          _marking = false;
          _markingStep = null;
          _markError = 'A selfie photo is required to mark attendance.';
        });
        return;
      }

      setState(() => _markingStep = 'Submitting…');
      final result = await AttendanceService.instance.markIn(
        lat: location.lat,
        lng: location.lng,
        photo: photo,
        deviceBiometricConfirmed: biometricConfirmed,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          _marking = false;
          _markingStep = null;
          _history = [result.data!, ..._history];
        });
      } else {
        setState(() {
          _marking = false;
          _markingStep = null;
          _markError = result.errorMessage;
        });
      }
    } on LocationPermissionDenied catch (e) {
      if (!mounted) return;
      setState(() {
        _marking = false;
        _markingStep = null;
        _markError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _marking = false;
        _markingStep = null;
        _markError = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _openLogMovement() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogMovementSheet(),
    );
    if (result == true) {
      // Movement logged — nothing to refresh on this screen, it's informational
      // toast-only, but keep the hook here in case a "recent movements" list
      // gets added to this screen later.
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _todayRecord;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            onPressed: _openLogMovement,
            icon: const Icon(Icons.directions_walk_rounded),
            tooltip: 'Log Movement',
          ),
          const NotificationBell(),
          const LogoutAction(),
        ],
      ),
      drawer: AppDrawer(role: 'sec', currentKey: 'attendance', user: widget.user),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _TodayCard(
              record: today,
              marking: _marking,
              markingStep: _markingStep,
              errorMessage: _markError,
              onMarkAttendance: _markAttendance,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Text('Recent History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openLogMovement,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                  label: const Text('Log Movement'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingHistory)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              )
            else if (_loadError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(_loadError!, style: const TextStyle(color: AppColors.inkMuted)),
              )
            else if (_history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('No attendance records yet.', style: TextStyle(color: AppColors.inkFaint)),
                ),
              )
            else
              ..._history.map((r) => _HistoryTile(record: r)),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.record,
    required this.marking,
    required this.markingStep,
    required this.errorMessage,
    required this.onMarkAttendance,
  });

  final AttendanceRecord? record;
  final bool marking;
  final String? markingStep;
  final String? errorMessage;
  final VoidCallback onMarkAttendance;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = '${_weekday(now.weekday)}, ${now.day} ${_month(now.month)} ${now.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: record != null
            ? LinearGradient(colors: [AppColors.success, AppColors.success.withValues(alpha: 0.85)])
            : AppColors.brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.primary500.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLabel, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            record != null ? "You're marked ${record!.isLate ? 'late' : 'present'} today" : "You haven't marked attendance today",
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.3),
          ),
          const SizedBox(height: 18),
          if (record != null) ...[
            Row(
              children: [
                _pill(Icons.access_time_rounded, formatTime12h(record!.checkInTime)),
                const SizedBox(width: 8),
                _pill(
                  record!.insideGeofence ? Icons.location_on_rounded : Icons.location_off_rounded,
                  record!.insideGeofence ? 'On premises' : 'Outside geofence',
                ),
              ],
            ),
          ] else if (marking) ...[
            Row(
              children: [
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    markingStep ?? 'Working…',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onMarkAttendance,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Mark Attendance'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary700),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ).animate().shake(duration: 400.ms, hz: 4),
            ],
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _weekday(int d) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
  String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
      ][m - 1];
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final statusColor = record.isLate ? AppColors.warning : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (record.photoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                record.photoUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _photoFallback(),
              ),
            )
          else
            _photoFallback(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.attendanceDate ?? '—', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                  '${formatTime12h(record.checkInTime)} · ${record.unionCouncil ?? ''}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(label: record.isLate ? 'Late' : 'Present', color: statusColor),
              const SizedBox(height: 4),
              Icon(
                record.insideGeofence ? Icons.check_circle_rounded : Icons.warning_rounded,
                size: 14,
                color: record.insideGeofence ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoFallback() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.person_rounded, color: AppColors.inkFaint),
    );
  }
}

class _LogMovementSheet extends StatefulWidget {
  const _LogMovementSheet();

  @override
  State<_LogMovementSheet> createState() => _LogMovementSheetState();
}

class _LogMovementSheetState extends State<_LogMovementSheet> {
  String _reason = _movementReasons.first;
  final _detailsController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    double? lat;
    double? lng;
    try {
      final position = await LocationService.instance.getCurrentPosition();
      lat = position.lat;
      lng = position.lng;
    } catch (_) {
      // Movement can still be logged without a location fix.
    }

    final result = await AttendanceService.instance.logMovement(
      reason: _reason,
      details: _detailsController.text.trim(),
      lat: lat,
      lng: lng,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _error = result.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            const Text('Log Movement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text('Let your ADLG know why you left your UC', style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
            const SizedBox(height: 20),
            const Text('Reason', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _movementReasons.map((r) {
                final selected = r == _reason;
                return ChoiceChip(
                  label: Text(r),
                  selected: selected,
                  onSelected: (_) => setState(() => _reason = r),
                  selectedColor: AppColors.primary50,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary700 : AppColors.inkMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  side: BorderSide(color: selected ? AppColors.primary400 : AppColors.border),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            const Text('Details (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Add a note…'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : const Text('Log Movement'),
            ),
          ],
        ),
      ),
    );
  }
}
