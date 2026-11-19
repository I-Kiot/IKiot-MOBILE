import '../../core/network/api_client.dart';
import '../../core/paged.dart';
import 'app_notification.dart';

/// Hộp thư của chính mình (`/notifications`). BE chỉ trả thông báo gửi cho người gọi.
class NotificationsRepository {
  const NotificationsRepository(this._api);

  final ApiClient _api;

  Future<Paged<AppNotification>> list({int page = 1, int limit = 20}) async {
    final body = await _api.get(
      '/notifications',
      query: {'page': page, 'limit': limit},
    ) as Map<String, dynamic>;
    return Paged.fromJson(body, AppNotification.fromJson);
  }

  Future<void> markRead(String id) => _api.patch('/notifications/$id/read');

  Future<void> markAllRead() => _api.patch('/notifications/read-all');
}
