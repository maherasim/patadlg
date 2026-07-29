import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/notification_center_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';

/// Drop into any screen's AppBar.actions — same CaseNotification feed the web
/// app's bell icon reads from, so anything sent as a push also has a
/// permanent home here (read/unread state, full history), not just a
/// one-shot system tray popup that's gone once dismissed.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unreadCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refreshCount();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshCount());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshCount() async {
    try {
      final feed = await NotificationCenterService.instance.fetch();
      if (!mounted) return;
      setState(() => _unreadCount = feed.unreadCount);
    } catch (_) {
      // Best-effort — badge just stays at its last known value.
    }
  }

  Future<void> _open() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotificationSheet(),
    );
    _refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _open,
      tooltip: 'Notifications',
      icon: Badge(
        isLabelVisible: _unreadCount > 0,
        label: Text(_unreadCount > 9 ? '9+' : '$_unreadCount'),
        backgroundColor: AppColors.danger,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _NotificationSheet extends StatefulWidget {
  const _NotificationSheet();

  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  bool _loading = true;
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final feed = await NotificationCenterService.instance.fetch();
      if (!mounted) return;
      setState(() {
        _notifications = feed.notifications;
        _unreadCount = feed.unreadCount;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.read) return;
    await NotificationCenterService.instance.markRead(n.id);
    _load();
  }

  Future<void> _markAllRead() async {
    await NotificationCenterService.instance.markAllRead();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  ),
                  if (_unreadCount > 0)
                    TextButton(onPressed: _markAllRead, child: const Text('Mark all read')),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                  : _notifications.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No notifications yet.', style: TextStyle(color: AppColors.inkFaint)),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final n = _notifications[index];
                            return InkWell(
                              onTap: () => _markRead(n),
                              child: Container(
                                color: n.read ? Colors.transparent : AppColors.primary50.withValues(alpha: 0.4),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!n.read)
                                      Container(
                                        margin: const EdgeInsets.only(top: 5, right: 8),
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(color: AppColors.primary500, shape: BoxShape.circle),
                                      )
                                    else
                                      const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(n.message, style: const TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.4)),
                                          const SizedBox(height: 4),
                                          Text(timeAgo(n.createdAt), style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
