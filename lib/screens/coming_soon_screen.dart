import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/logout_action.dart';
import '../widgets/notification_bell.dart';

/// Placeholder for sections that exist in the web sidebar but haven't been
/// built into the app yet — keeps the drawer's full nav map visible and
/// professional now, so each future module just swaps this out for a real
/// screen without touching the navigation shell.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.role,
    required this.user,
    required this.currentKey,
    required this.title,
    required this.icon,
  });

  final String role;
  final Map<String, dynamic> user;
  final String currentKey;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: Text(title), actions: const [NotificationBell(), LogoutAction()]),
      drawer: AppDrawer(role: role, currentKey: currentKey, user: user),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(24)),
                child: Icon(icon, size: 36, color: Colors.white),
              ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.85, 0.85)),
              const SizedBox(height: 22),
              Text(
                '$title is coming soon',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'This section is being built for the app and will appear here shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
