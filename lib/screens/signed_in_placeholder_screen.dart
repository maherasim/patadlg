import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

const Map<String, String> _roleLabels = {
  'sa': 'Super Admin',
  'adlg': 'ADLG',
  'ddlg': 'DDLG',
  'sec': 'Secretary UC',
};

/// A checkpoint screen, not the real dashboard — proves the live login round-trip
/// (CSRF + session cookie + /api/login) actually works end to end. The real
/// role-specific dashboards get built next, once this is confirmed on a device.
class SignedInPlaceholderScreen extends StatefulWidget {
  const SignedInPlaceholderScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<SignedInPlaceholderScreen> createState() => _SignedInPlaceholderScreenState();
}

class _SignedInPlaceholderScreenState extends State<SignedInPlaceholderScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['name']?.toString() ?? 'User';
    final role = widget.user['role']?.toString() ?? '';
    final roleLabel = _roleLabels[role] ?? role;
    final username = widget.user['username']?.toString();

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 46),
              ).animate().scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 500.ms).fadeIn(),
              const SizedBox(height: 24),
              const Text(
                "You're signed in",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
              const SizedBox(height: 8),
              Text(
                'Login is fully wired to the live API.\nThe $roleLabel dashboard comes next.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.inkMuted, height: 1.5, fontWeight: FontWeight.w500),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(label: 'Name', value: name),
                    if (username != null) _InfoRow(label: 'Username', value: username),
                    _InfoRow(label: 'Role', value: roleLabel, isLast: true),
                  ],
                ),
              ).animate().fadeIn(delay: 280.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loggingOut ? null : _logout,
                  icon: _loggingOut
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.logout_rounded, size: 18),
                  label: Text(_loggingOut ? 'Signing out…' : 'Sign Out'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.isLast = false});

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.inkFaint, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.ink, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
