import 'package:flutter/material.dart';

import 'adlg/attendance_screen.dart';
import 'adlg/dashboard_screen.dart';
import 'adlg/reports_screen.dart';
import 'coming_soon_screen.dart';
import 'sec/attendance_screen.dart';
import 'sec/biometric_enrollment_screen.dart';
import 'sec/dashboard_screen.dart';
import 'sec/first_login_password_screen.dart';
import 'sec/reports_screen.dart';
import 'signed_in_placeholder_screen.dart';

const Map<String, IconData> _kNavIcons = {
  'dashboard': Icons.grid_view_rounded,
  'attendance': Icons.fingerprint_rounded,
  'reports': Icons.assignment_outlined,
  'cases': Icons.gavel_rounded,
  'lbr': Icons.child_friendly_rounded,
  'ldr': Icons.inventory_2_outlined,
  'dklic': Icons.menu_book_rounded,
  'chatbot': Icons.chat_bubble_outline_rounded,
  'profile': Icons.settings_outlined,
  'union-councils': Icons.account_balance_rounded,
  'secretaries': Icons.badge_outlined,
  'newsletters': Icons.newspaper_rounded,
  'inquiries': Icons.description_outlined,
};

const Map<String, String> _kNavLabels = {
  'dashboard': 'Dashboard',
  'attendance': 'Attendance',
  'reports': 'Reports',
  'cases': 'Divorce/Khula Cases',
  'lbr': 'Birth Registration',
  'ldr': 'Death Registration',
  'dklic': 'Local Government Library',
  'chatbot': 'Local Government Chatbot',
  'profile': 'Settings',
  'union-councils': 'Union Councils',
  'secretaries': 'Secretaries',
  'newsletters': 'Newsletters',
  'inquiries': 'Inquiry',
};

/// Picks the right home screen for a freshly-authenticated user. Only
/// Secretary and ADLG have real screens so far (Dashboard + Attendance) —
/// every other role still lands on the signed-in checkpoint until their
/// screens are built.
Widget screenForUser(Map<String, dynamic> user) {
  switch (user['role']) {
    case 'sec':
      final firstLogin = user['first_login'] as bool? ?? false;
      if (firstLogin) return FirstLoginPasswordScreen(user: user);
      final enrolled = (user['secretary_profile'] as Map?)?['device_biometric_enrolled'] as bool? ?? false;
      return enrolled ? SecDashboardScreen(user: user) : BiometricEnrollmentScreen(user: user);
    case 'adlg':
      return AdlgDashboardScreen(user: user);
    default:
      return SignedInPlaceholderScreen(user: user);
  }
}

/// Resolves a drawer nav key ('dashboard', 'attendance', 'cases', ...) to the
/// screen it should navigate to for a given role — real screens where built,
/// ComingSoonScreen everywhere else. This is what the AppDrawer/sidebar uses
/// so new modules just slot in here without touching the navigation shell.
Widget screenForKey({required String role, required String navKey, required Map<String, dynamic> user}) {
  if (navKey == 'dashboard') {
    return role == 'adlg' ? AdlgDashboardScreen(user: user) : SecDashboardScreen(user: user);
  }
  if (navKey == 'attendance') {
    return role == 'adlg' ? AdlgAttendanceScreen(user: user) : SecAttendanceScreen(user: user);
  }
  if (navKey == 'reports') {
    return role == 'adlg' ? AdlgReportsScreen(user: user) : SecReportsScreen(user: user);
  }

  return ComingSoonScreen(
    role: role,
    user: user,
    currentKey: navKey,
    title: _kNavLabels[navKey] ?? 'Coming Soon',
    icon: _kNavIcons[navKey] ?? Icons.hourglass_bottom_rounded,
  );
}
