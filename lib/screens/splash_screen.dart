import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/location_tracking_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'role_router.dart';
import 'terms_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final stopwatch = Stopwatch()..start();

    await ApiClient.instance.init();
    final seenOnboarding = await AuthService.instance.hasSeenOnboarding();
    final acceptedTerms = await AuthService.instance.hasAcceptedTerms();

    // Try to resume an existing session (cookie jar is persisted to disk, so
    // it survives the app being closed) instead of always forcing a fresh
    // login — /api/me returns null on an expired/missing session.
    Map<String, dynamic>? resumedUser;
    if (seenOnboarding && acceptedTerms) {
      resumedUser = await AuthService.instance.currentUser();
    }

    // Keep the brand moment on screen for at least this long, animation included,
    // regardless of how fast the above finished — a splash that flashes for 40ms
    // reads as broken, not fast.
    const minDisplay = Duration(milliseconds: 1900);
    final elapsed = stopwatch.elapsed;
    if (elapsed < minDisplay) {
      await Future.delayed(minDisplay - elapsed);
    }

    if (!mounted) return;

    Widget next;
    if (!seenOnboarding) {
      next = const OnboardingScreen();
    } else if (!acceptedTerms) {
      next = const TermsScreen();
    } else if (resumedUser != null) {
      if (resumedUser['role'] == 'sec') {
        unawaited(LocationTrackingService.instance.ensureStartedForSecretary());
      }
      unawaited(NotificationService.instance.registerToken());
      next = screenForUser(resumedUser);
    } else {
      next = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, animation, _) => next,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 128,
                  height: 128,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/icon/app_icon_foreground.png', fit: BoxFit.cover),
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1, 1),
                      duration: 650.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 450.ms),
                const SizedBox(height: 28),
                Text(
                  "PA TO AD'sLG",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ).animate().fadeIn(delay: 350.ms, duration: 500.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 8),
                Text(
                  'Personal Assistant to ADLG\nfor UCs\' Management',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
                const SizedBox(height: 56),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.85)),
                  ),
                ).animate().fadeIn(delay: 700.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
