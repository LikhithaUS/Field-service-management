import '../core/constants/api_constants.dart';
import '../core/utils/api_dates.dart';
import '../models/leave.dart';
import '../models/leave_query.dart';
import '../models/paginated.dart';
import 'api_service.dart';

class LeaveService {
  LeaveService(this._api);

  final ApiService _api;

  Future<Paginated<LeaveRequest>> list(LeaveQuery query) async {
    final body = await _api.get(ApiConstants.leaves, query: query.toQueryParameters());
    return Paginated.fromJson(body['data'] as Map<String, dynamic>, LeaveRequest.fromJson);
  }

  Future<LeaveRequest> get(String id) async => _unwrap(await _api.get('${ApiConstants.leaves}/$id'));

  Future<LeaveRequest> apply({
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final body = await _api.post(ApiConstants.leaves, data: {
      'leaveType': leaveType.apiValue,
      'startDate': ApiDates.toDay(startDate),
      'endDate': ApiDates.toDay(endDate),
      'reason': reason,
    });
    return _unwrap(body);
  }

  Future<LeaveRequest> approve(String id, {String note = ''}) async =>
      _unwrap(await _api.put('${ApiConstants.leaves}/$id/approve', data: {'note': note}));

  Future<LeaveRequest> reject(String id, {String note = ''}) async =>
      _unwrap(await _api.put('${ApiConstants.leaves}/$id/reject', data: {'note': note}));

  Future<LeaveRequest> cancel(String id) async => _unwrap(await _api.put('${ApiConstants.leaves}/$id/cancel'));

  LeaveRequest _unwrap(Map<String, dynamic> body) =>
      LeaveRequest.fromJson((body['data'] as Map<String, dynamic>)['leave'] as Map<String, dynamic>);
}
