import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Guarded internally — safe even before/without an iOS GoogleService-Info.plist.
  await NotificationService.instance.init();
  runApp(const PaToAdlgApp());
}

class PaToAdlgApp extends StatelessWidget {
  const PaToAdlgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "PA TO AD'sLG",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
