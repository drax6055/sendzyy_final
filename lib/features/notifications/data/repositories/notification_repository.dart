import '../datasources/notification_remote_datasource.dart';

class NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;

  NotificationRepository({required this.remoteDataSource});

  Future<Map<String, dynamic>> fetchNotifications({
    required String tenantId,
    int page = 1,
    int limit = 20,
    String category = 'all',
    bool unreadOnly = false,
  }) async {
    return await remoteDataSource.getNotifications(
      tenantId: tenantId,
      page: page,
      limit: limit,
      category: category,
      unreadOnly: unreadOnly,
    );
  }

  Future<int> getUnreadCount({required String tenantId}) async {
    return await remoteDataSource.getUnreadCount(tenantId: tenantId);
  }

  Future<int> markRead({
    required String notificationId,
    required String tenantId,
  }) async {
    return await remoteDataSource.markRead(
      notificationId: notificationId,
      tenantId: tenantId,
    );
  }

  Future<void> markAllRead({required String tenantId}) async {
    await remoteDataSource.markAllRead(tenantId: tenantId);
  }

  Future<int> deleteNotification({
    required String notificationId,
    required String tenantId,
  }) async {
    return await remoteDataSource.deleteNotification(
      notificationId: notificationId,
      tenantId: tenantId,
    );
  }

  Future<int> clearAllNotifications({
    required String tenantId,
    String? category,
  }) async {
    return await remoteDataSource.clearAllNotifications(
      tenantId: tenantId,
      category: category,
    );
  }
}
