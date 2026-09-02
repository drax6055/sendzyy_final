import 'package:dio/dio.dart';
import '../models/notification_model.dart';

class NotificationRemoteDataSource {
  final Dio dio;

  NotificationRemoteDataSource({required this.dio});

  Future<void> registerFcmToken({
    required String tenantId,
    required String token,
    required String platform,
    String? deviceId,
    String? deviceName,
    String? appVersion,
  }) async {
    await dio.post(
      '/api/notifications/register-token',
      data: {
        'tenantId': tenantId,
        'token': token,
        'platform': platform,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'appVersion': appVersion,
      },
    );
  }

  Future<Map<String, dynamic>> getNotifications({
    required String tenantId,
    int page = 1,
    int limit = 20,
    String category = 'all',
    bool unreadOnly = false,
  }) async {
    final response = await dio.get(
      '/api/notifications',
      queryParameters: {
        'tenantId': tenantId,
        'page': page,
        'limit': limit,
        'category': category,
        'unreadOnly': unreadOnly,
      },
      options: Options(headers: {'tenant-id': tenantId}),
    );

    final List rawList = response.data['notifications'] ?? [];
    final List<NotificationModel> notifications =
        rawList.map((e) => NotificationModel.fromJson(e)).toList();

    return {
      'notifications': notifications,
      'total': response.data['total'] ?? 0,
      'unreadCount': response.data['unreadCount'] ?? 0,
      'page': response.data['page'] ?? 1,
      'pages': response.data['pages'] ?? 1,
    };
  }

  Future<int> getUnreadCount({required String tenantId}) async {
    final response = await dio.get(
      '/api/notifications/count',
      queryParameters: {'tenantId': tenantId},
      options: Options(headers: {'tenant-id': tenantId}),
    );
    return response.data['unreadCount'] ?? 0;
  }

  Future<int> markRead({required String notificationId, required String tenantId}) async {
    final response = await dio.patch(
      '/api/notifications/$notificationId/read',
      data: {'tenantId': tenantId},
      options: Options(headers: {'tenant-id': tenantId}),
    );
    return response.data['unreadCount'] ?? 0;
  }

  Future<void> markAllRead({required String tenantId}) async {
    await dio.patch(
      '/api/notifications/mark-all-read',
      data: {'tenantId': tenantId},
      options: Options(headers: {'tenant-id': tenantId}),
    );
  }

  Future<int> deleteNotification({
    required String notificationId,
    required String tenantId,
  }) async {
    final response = await dio.delete(
      '/api/notifications/$notificationId',
      queryParameters: {'tenantId': tenantId},
      options: Options(headers: {'tenant-id': tenantId}),
    );
    return response.data['unreadCount'] ?? 0;
  }

  Future<int> clearAllNotifications({
    required String tenantId,
    String? category,
  }) async {
    final response = await dio.delete(
      '/api/notifications/clear-all',
      queryParameters: {
        'tenantId': tenantId,
        if (category != null && category != 'all') 'category': category,
      },
      options: Options(headers: {'tenant-id': tenantId}),
    );
    return response.data['unreadCount'] ?? 0;
  }
}
