import 'package:flutter/material.dart';

import 'adlg/attendance_screen.dart';
import 'adlg/cases_screen.dart';
import 'adlg/dashboard_screen.dart';
import 'adlg/lbr_screen.dart';
import 'adlg/reports_screen.dart';
import 'adlg/secretaries_screen.dart';
import 'adlg/union_councils_screen.dart';
import 'coming_soon_screen.dart';
import 'ddlg/adlgs_screen.dart';
import 'ddlg/dashboard_screen.dart';
import 'ddlg/lbr_screen.dart';
import 'ddlg/reports_screen.dart';
import 'ddlg/secretaries_screen.dart';
import 'ddlg/tehsils_screen.dart';
import 'ddlg/union_councils_screen.dart';
import 'sec/attendance_screen.dart';
import 'sec/biometric_enrollment_screen.dart';
import 'sec/cases_screen.dart';
import 'sec/dashboard_screen.dart';
import 'sec/first_login_password_screen.dart';
import 'sec/lbr_screen.dart';
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
  'tehsils': Icons.map_outlined,
  'adlgs': Icons.groups_outlined,
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
  'tehsils': 'Tehsils',
  'adlgs': 'ADLGs',
};

/// Picks the right home screen for a freshly-authenticated user. Secretary,
/// ADLG, and DDLG all have real dashboards now — any other role still lands
/// on the signed-in checkpoint until its screens are built.
Widget screenForUser(Map<String, dynamic> user) {
  switch (user['role']) {
    case 'sec':
      final firstLogin = user['first_login'] as bool? ?? false;
      if (firstLogin) return FirstLoginPasswordScreen(user: user);
      final enrolled = (user['secretary_profile'] as Map?)?['device_biometric_enrolled'] as bool? ?? false;
      return enrolled ? SecDashboardScreen(user: user) : BiometricEnrollmentScreen(user: user);
    case 'adlg':
      return AdlgDashboardScreen(user: user);
    case 'ddlg':
      return DdlgDashboardScreen(user: user);
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
    if (role == 'adlg') return AdlgDashboardScreen(user: user);
    if (role == 'ddlg') return DdlgDashboardScreen(user: user);
    return SecDashboardScreen(user: user);
  }
  if (navKey == 'attendance' && role != 'ddlg') {
    return role == 'adlg' ? AdlgAttendanceScreen(user: user) : SecAttendanceScreen(user: user);
  }
  if (navKey == 'reports') {
    if (role == 'adlg') return AdlgReportsScreen(user: user);
    if (role == 'ddlg') return DdlgReportsScreen(user: user);
    return SecReportsScreen(user: user);
  }
  if (navKey == 'cases' && role != 'ddlg') {
    return role == 'adlg' ? AdlgCasesScreen(user: user) : SecCasesScreen(user: user);
  }
  if (navKey == 'lbr') {
    if (role == 'adlg') return AdlgLbrScreen(user: user);
    if (role == 'ddlg') return DdlgLbrScreen(user: user);
    return SecLbrScreen(user: user);
  }
  if (navKey == 'union-councils') {
    if (role == 'adlg') return AdlgUnionCouncilsScreen(user: user);
    if (role == 'ddlg') return DdlgUnionCouncilsScreen(user: user);
  }
  if (navKey == 'secretaries') {
    if (role == 'adlg') return AdlgSecretariesScreen(user: user);
    if (role == 'ddlg') return DdlgSecretariesScreen(user: user);
  }
  if (navKey == 'tehsils' && role == 'ddlg') return DdlgTehsilsScreen(user: user);
  if (navKey == 'adlgs' && role == 'ddlg') return DdlgAdlgsScreen(user: user);

  return ComingSoonScreen(
    role: role,
    user: user,
    currentKey: navKey,
    title: _kNavLabels[navKey] ?? 'Coming Soon',
    icon: _kNavIcons[navKey] ?? Icons.hourglass_bottom_rounded,
  );
}
