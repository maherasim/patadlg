import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/location_tracking_service.dart';
import '../services/notification_service.dart';
import '../screens/login_screen.dart';

/// Drop into any role screen's AppBar.actions — confirms, stops background
/// tracking if it was running, clears the session, and returns to Login.
class LogoutAction extends StatelessWidget {
  const LogoutAction({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text("You'll need to sign in again to continue."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    await LocationTrackingService.instance.stop();
    await NotificationService.instance.unregisterToken();
    await AuthService.instance.logout();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _logout(context),
      icon: const Icon(Icons.logout_rounded),
      tooltip: 'Sign Out',
    );
  }
}
