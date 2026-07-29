import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/auth_service.dart';
import '../services/location_tracking_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'role_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _remember = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final result = await AuthService.instance.login(
      login: _loginController.text.trim(),
      password: _passwordController.text,
      remember: _remember,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      // Best-effort, never blocks navigation — a failed token registration
      // just means this device won't get pushes until the next app launch.
      unawaited(NotificationService.instance.registerToken());

      // Secretary location tracking must run whether or not the Attendance
      // screen is ever opened — start it right at login, not per-screen.
      if (result.user!['role'] == 'sec') {
        unawaited(LocationTrackingService.instance.ensureStartedForSecretary());
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => screenForUser(result.user!)),
      );
      return;
    }

    setState(() {
      _submitting = false;
      _errorMessage = result.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 28),
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary500.withValues(alpha: 0.14), blurRadius: 24, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset('assets/icon/app_icon_foreground.png', fit: BoxFit.cover),
                          ),
                        ),
                      ).animate().fadeIn(duration: 450.ms).slideY(begin: -0.15, end: 0, curve: Curves.easeOut),
                      const SizedBox(height: 20),
                      const Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                      const SizedBox(height: 6),
                      const Text(
                        "Sign in to PA TO AD'sLG",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.inkMuted, fontWeight: FontWeight.w500),
                      ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
                      const SizedBox(height: 36),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Username or Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _loginController,
                              autofillHints: const [AutofillHints.username, AutofillHints.email],
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'e.g. sa@demo.pk',
                                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your username or email' : null,
                            ),
                            const SizedBox(height: 18),
                            const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    size: 20,
                                    color: AppColors.inkMuted,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _remember,
                                    onChanged: (v) => setState(() => _remember = v ?? true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('Keep me signed in', style: TextStyle(fontSize: 13, color: AppColors.inkMuted, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().shake(duration: 400.ms, hz: 4),
                            ],
                            const SizedBox(height: 22),
                            ElevatedButton(
                              onPressed: _submitting ? null : _submit,
                              child: _submitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                    )
                                  : const Text('Sign In'),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 450.ms),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          '© ${DateTime.now().year} Bakhtawar Shahzad AI Labs Pvt Ltd.\nAll rights reserved.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: AppColors.inkFaint, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
