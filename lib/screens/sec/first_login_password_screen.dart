import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/logout_action.dart';
import 'biometric_enrollment_screen.dart';
import 'dashboard_screen.dart';

/// Mandatory first-login step, mirroring the web app's FirstLoginSetup.jsx —
/// same endpoint/contract, same rule (min 6 characters, nothing else; any
/// mix of letters/numbers/symbols the secretary wants is fine). No skip.
class FirstLoginPasswordScreen extends StatefulWidget {
  const FirstLoginPasswordScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<FirstLoginPasswordScreen> createState() => _FirstLoginPasswordScreenState();
}

class _FirstLoginPasswordScreenState extends State<FirstLoginPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final result = await ProfileService.instance.completeFirstLogin(
      password: _passwordController.text,
      passwordConfirmation: _confirmController.text,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _submitting = false;
        _errorMessage = result.errorMessage;
      });
      return;
    }

    final updatedUser = result.user!;
    final enrolled = (updatedUser['secretary_profile'] as Map?)?['device_biometric_enrolled'] as bool? ?? false;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => enrolled ? SecDashboardScreen(user: updatedUser) : BiometricEnrollmentScreen(user: updatedUser),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Set New Password'), automaticallyImplyLeading: false, actions: const [LogoutAction()]),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(26)),
                  child: const Icon(Icons.lock_reset_rounded, size: 44, color: Colors.white),
                ),
              ).animate().fadeIn(duration: 450.ms).scale(begin: const Offset(0.85, 0.85)),
              const SizedBox(height: 24),
              const Text(
                'Welcome — let\'s secure your account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 8),
              const Text(
                "This is your first time signing in — choose a new password before you continue.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.inkMuted, height: 1.5, fontWeight: FontWeight.w500),
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'At least 6 characters',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppColors.inkMuted),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter a new password';
                        if (v.length < 6) return 'Must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text('Confirm Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: 'Re-enter your new password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppColors.inkMuted),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Re-enter your new password';
                        if (v != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
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
                            Expanded(child: Text(_errorMessage!, style: const TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ).animate().shake(duration: 400.ms, hz: 4),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : const Text('Continue'),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 450.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
