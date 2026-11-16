import '../core/constants/api_constants.dart';
import '../models/announcement.dart';
import '../models/paginated.dart';
import 'api_service.dart';

class AnnouncementService {
  AnnouncementService(this._api);

  final ApiService _api;

  Future<Paginated<Announcement>> list({AnnouncementCategory? category, String search = '', int page = 1, int limit = 10}) async {
    final body = await _api.get(ApiConstants.announcements, query: {
      'page': page,
      'limit': limit,
      if (category != null) 'category': category.apiValue,
      if (search.isNotEmpty) 'search': search,
    });
    return Paginated.fromJson(body['data'] as Map<String, dynamic>, Announcement.fromJson);
  }

  Future<Announcement> get(String id) async => _unwrap(await _api.get('${ApiConstants.announcements}/$id'));

  Future<Announcement> create(Map<String, dynamic> data) async =>
      _unwrap(await _api.post(ApiConstants.announcements, data: data));

  Future<Announcement> update(String id, Map<String, dynamic> data) async =>
      _unwrap(await _api.put('${ApiConstants.announcements}/$id', data: data));

  Future<void> delete(String id) => _api.delete('${ApiConstants.announcements}/$id');

  Announcement _unwrap(Map<String, dynamic> body) =>
      Announcement.fromJson((body['data'] as Map<String, dynamic>)['announcement'] as Map<String, dynamic>);
}
