import 'package:dio/dio.dart';

import '../models/app_notification.dart';
import 'api_client.dart';

class NotificationFeed {
  NotificationFeed({required this.notifications, required this.unreadCount});

  final List<AppNotification> notifications;
  final int unreadCount;
}

/// The in-app notification center — same CaseNotification records the web
/// app's bell icon reads, so anything that arrives as a push also shows up
/// here for later reference (read/unread state, history), not just as a
/// one-off system tray popup.
class NotificationCenterService {
  NotificationCenterService._();

  static final NotificationCenterService instance = NotificationCenterService._();

  Dio get _dio => ApiClient.instance.dio;

  Future<NotificationFeed> fetch() async {
    final response = await _dio.get('/api/notifications');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    final unread = (response.data['meta']?['unread_count'] as num?)?.toInt() ?? 0;
    return NotificationFeed(notifications: list.map(AppNotification.fromJson).toList(), unreadCount: unread);
  }

  Future<void> markRead(int id) async {
    try {
      await _dio.post('/api/notifications/$id/read');
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.post('/api/notifications/read-all');
    } catch (_) {
      // Best-effort.
    }
  }
}
