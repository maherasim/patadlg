import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/attendance_service.dart';
import '../../services/biometric_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/logout_action.dart';
import 'dashboard_screen.dart';

/// A mandatory, non-skippable gate a Secretary must clear right after their
/// first login (and reachable again later to re-register on a new phone) —
/// stronger than the web app's optional WebAuthn enrollment step. The point
/// is simple: attendance is only meaningful if it's actually the assigned
/// secretary's own fingerprint confirming it, every single time, not
/// whoever happens to be holding the phone.
class BiometricEnrollmentScreen extends StatefulWidget {
  const BiometricEnrollmentScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<BiometricEnrollmentScreen> createState() => _BiometricEnrollmentScreenState();
}

enum _CapabilityCheck { checking, available, unavailable }

class _BiometricEnrollmentScreenState extends State<BiometricEnrollmentScreen> {
  _CapabilityCheck _capability = _CapabilityCheck.checking;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkCapability();
  }

  Future<void> _checkCapability() async {
    final available = await BiometricService.instance.isAvailable();
    if (!mounted) return;
    setState(() => _capability = available ? _CapabilityCheck.available : _CapabilityCheck.unavailable);
  }

  Future<void> _register() async {
    setState(() {
      _working = true;
      _error = null;
    });

    final result = await BiometricService.instance.authenticateWithDetail(
      reason: 'Register your fingerprint for secure attendance',
    );

    if (!result.succeeded) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = result.message;
      });
      return;
    }

    final saved = await AttendanceService.instance.enrollBiometric();
    if (!mounted) return;

    if (!saved) {
      setState(() {
        _working = false;
        _error = "Couldn't save your registration. Check your connection and try again.";
      });
      return;
    }

    _goToDashboard();
  }

  Future<void> _continueWithoutBiometric() async {
    setState(() => _working = true);
    // Records that this secretary passed through the enrollment flow — no
    // real fingerprint was captured (this device can't do it), so mark-in's
    // own biometric check will simply stay optional on this device, exactly
    // as it already does for any device without biometric hardware.
    await AttendanceService.instance.enrollBiometric();
    if (!mounted) return;
    _goToDashboard();
  }

  /// Reached two ways: as the mandatory post-login gate (nothing to pop back
  /// to — replace with a fresh Dashboard) or as a later re-registration from
  /// the Dashboard's own quick action (pop back to the one already there).
  void _goToDashboard() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SecDashboardScreen(user: widget.user)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Secure Your Account'), automaticallyImplyLeading: false, actions: const [LogoutAction()]),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(30)),
                child: const Icon(Icons.fingerprint_rounded, size: 54, color: Colors.white),
              ).animate().fadeIn(duration: 450.ms).scale(begin: const Offset(0.85, 0.85)),
              const SizedBox(height: 28),
              const Text(
                'Register Your Fingerprint',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.ink),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 10),
              const Text(
                "For your security, only you should be able to mark your own attendance. Register your fingerprint once — you'll confirm it every time you check in.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.inkMuted, height: 1.55, fontWeight: FontWeight.w500),
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
              const SizedBox(height: 36),
              if (_capability == _CapabilityCheck.checking)
                const CircularProgressIndicator(strokeWidth: 2.4)
              else if (_capability == _CapabilityCheck.available) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _working ? null : _register,
                    icon: _working
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                        : const Icon(Icons.fingerprint_rounded),
                    label: Text(_working ? 'Registering…' : 'Register Fingerprint'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ).animate().shake(duration: 400.ms, hz: 4),
                ],
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
                  ),
                  child: const Text(
                    "This device doesn't support fingerprint or face verification. You can continue, but a device with biometric hardware is recommended for full attendance security.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppColors.warning, fontWeight: FontWeight.w600, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _working ? null : _continueWithoutBiometric,
                    child: _working
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
                        : const Text('Continue Without Fingerprint'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
