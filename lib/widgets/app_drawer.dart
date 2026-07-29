import 'package:flutter/material.dart';

import '../screens/role_router.dart';
import '../services/auth_service.dart';
import '../services/location_tracking_service.dart';
import '../services/notification_service.dart';
import '../screens/login_screen.dart';
import '../theme/app_theme.dart';

class DrawerNavItem {
  const DrawerNavItem({required this.navKey, required this.label, required this.icon});

  final String navKey;
  final String label;
  final IconData icon;
}

class DrawerNavGroup {
  const DrawerNavGroup({required this.label, required this.items});

  final String label;
  final List<DrawerNavItem> items;
}

/// Mirrors SecLayout.jsx's NAV_GROUPS exactly (same labels, same grouping,
/// same route keys) so the app and the web dashboard read as one product.
const List<DrawerNavGroup> kSecNavGroups = [
  DrawerNavGroup(label: 'Overview', items: [
    DrawerNavItem(navKey: 'dashboard', label: 'Dashboard', icon: Icons.grid_view_rounded),
  ]),
  DrawerNavGroup(label: 'Daily Duties', items: [
    DrawerNavItem(navKey: 'attendance', label: 'Attendance', icon: Icons.fingerprint_rounded),
    DrawerNavItem(navKey: 'reports', label: 'Reports', icon: Icons.assignment_outlined),
  ]),
  DrawerNavGroup(label: 'Registry', items: [
    DrawerNavItem(navKey: 'cases', label: 'Divorce/Khula Cases', icon: Icons.gavel_rounded),
    DrawerNavItem(navKey: 'lbr', label: 'Birth Registration', icon: Icons.child_friendly_rounded),
    DrawerNavItem(navKey: 'ldr', label: 'Death Registration', icon: Icons.inventory_2_outlined),
  ]),
  DrawerNavGroup(label: 'Communications', items: [
    DrawerNavItem(navKey: 'dklic', label: 'Local Government Library', icon: Icons.menu_book_rounded),
    DrawerNavItem(navKey: 'chatbot', label: 'Local Government Chatbot', icon: Icons.chat_bubble_outline_rounded),
  ]),
  DrawerNavGroup(label: 'Account', items: [
    DrawerNavItem(navKey: 'profile', label: 'Settings', icon: Icons.settings_outlined),
  ]),
];

/// Mirrors AdlgLayout.jsx's NAV_GROUPS.
const List<DrawerNavGroup> kAdlgNavGroups = [
  DrawerNavGroup(label: 'Overview', items: [
    DrawerNavItem(navKey: 'dashboard', label: 'Dashboard', icon: Icons.grid_view_rounded),
  ]),
  DrawerNavGroup(label: 'Registry', items: [
    DrawerNavItem(navKey: 'cases', label: 'Divorce/Khula Cases', icon: Icons.gavel_rounded),
    DrawerNavItem(navKey: 'lbr', label: 'Birth Registration', icon: Icons.child_friendly_rounded),
    DrawerNavItem(navKey: 'ldr', label: 'Death Registration', icon: Icons.inventory_2_outlined),
  ]),
  DrawerNavGroup(label: 'Management', items: [
    DrawerNavItem(navKey: 'union-councils', label: 'Union Councils', icon: Icons.account_balance_rounded),
    DrawerNavItem(navKey: 'secretaries', label: 'Secretaries', icon: Icons.badge_outlined),
    DrawerNavItem(navKey: 'attendance', label: 'Attendance', icon: Icons.fingerprint_rounded),
    DrawerNavItem(navKey: 'reports', label: 'Reports', icon: Icons.assignment_outlined),
  ]),
  DrawerNavGroup(label: 'Communications', items: [
    DrawerNavItem(navKey: 'newsletters', label: 'Newsletters', icon: Icons.newspaper_rounded),
    DrawerNavItem(navKey: 'dklic', label: 'Local Government Library', icon: Icons.menu_book_rounded),
    DrawerNavItem(navKey: 'chatbot', label: 'Local Government Chatbot', icon: Icons.chat_bubble_outline_rounded),
    DrawerNavItem(navKey: 'inquiries', label: 'Inquiry', icon: Icons.description_outlined),
  ]),
  DrawerNavGroup(label: 'Account', items: [
    DrawerNavItem(navKey: 'profile', label: 'Settings', icon: Icons.settings_outlined),
  ]),
];

/// The mobile equivalent of the web sidebar — a slide-out navigation drawer
/// rather than a pinned column, since that's the native pattern for this many
/// destinations (9-13 per role) on a phone screen. Same grouping/labels as
/// the web app, swapped for a touch-first layout.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.role, required this.currentKey, required this.user});

  final String role;
  final String currentKey;
  final Map<String, dynamic> user;

  List<DrawerNavGroup> get _groups => role == 'adlg' ? kAdlgNavGroups : kSecNavGroups;

  String get _roleLabel => role == 'adlg' ? 'Assistant Director LG' : 'Secretary UC';

  String? get _subtitle {
    if (role == 'adlg') {
      final tehsil = (user['adlg_profile'] as Map?)?['tehsil'] as String?;
      return tehsil != null ? 'ADLG · $tehsil' : _roleLabel;
    }
    final uc = (user['secretary_profile'] as Map?)?['union_council'] as String?;
    return uc != null ? 'Secretary · $uc' : _roleLabel;
  }

  Future<void> _handleTap(BuildContext context, DrawerNavItem item) async {
    Navigator.of(context).pop();
    if (item.navKey == currentKey) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screenForKey(role: role, navKey: item.navKey, user: user)),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
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
    Navigator.of(context).pop();

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
    return Drawer(
      backgroundColor: AppColors.primary700,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('assets/icon/app_icon_foreground.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (user['name'] as String?) ?? "PA TO AD'sLG",
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle ?? _roleLabel,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11.5, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                children: [
                  for (final group in _groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                      child: Text(
                        group.label.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    for (final item in group.items) _DrawerTile(
                      item: item,
                      selected: item.navKey == currentKey,
                      onTap: () => _handleTap(context, item),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            _DrawerTile(
              item: const DrawerNavItem(navKey: '_logout', label: 'Sign Out', icon: Icons.logout_rounded),
              selected: false,
              onTap: () => _handleLogout(context),
              danger: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Text(
                '© ${DateTime.now().year} Bakhtawar Shahzad AI Labs Pvt Ltd.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({required this.item, required this.selected, required this.onTap, this.danger = false});

  final DrawerNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.accent400 : (selected ? Colors.white : Colors.white.withValues(alpha: 0.75));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppColors.accent500 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
