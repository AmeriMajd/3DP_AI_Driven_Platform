import '../domain/app_notification.dart';

class NotificationPage {
  final List<AppNotification> items;
  final DateTime? nextCursor;
  final int unreadCount;

  const NotificationPage({
    required this.items,
    required this.unreadCount,
    this.nextCursor,
  });
}

abstract class NotificationRepository {
  Future<NotificationPage> list({
    DateTime? cursor,
    int limit = 30,
    bool unreadOnly = false,
    String? category,
  });

  Future<int> getUnreadCount();

  Future<AppNotification> markRead(String notificationId);

  Future<int> markAllRead();

  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
    String? deviceLabel,
    String? appVersion,
  });

  Future<void> unregisterDevice(String fcmToken);
}
