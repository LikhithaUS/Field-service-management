import '../core/constants/api_constants.dart';
import '../models/app_notification.dart';
import '../models/paginated.dart';
import 'api_service.dart';

class NotificationService {
  NotificationService(this._api);

  final ApiService _api;

  Future<Paginated<AppNotification>> list({int page = 1, int limit = 20, bool unreadOnly = false}) async {
    final body = await _api.get(ApiConstants.notifications, query: {
      'page': page,
      'limit': limit,
      if (unreadOnly) 'unread': 'true',
    });
    return Paginated.fromJson(body['data'] as Map<String, dynamic>, AppNotification.fromJson);
  }

  Future<int> unreadCount() async {
    final body = await _api.get('${ApiConstants.notifications}/unread-count');
    return ((body['data'] as Map<String, dynamic>)['unreadCount'] as num).toInt();
  }

  Future<void> markRead(String id) => _api.put('${ApiConstants.notifications}/$id/read');

  Future<void> markAllRead() => _api.put('${ApiConstants.notifications}/read-all');
}
