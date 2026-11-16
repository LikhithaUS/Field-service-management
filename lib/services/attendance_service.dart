import '../core/constants/api_constants.dart';
import '../models/attendance.dart';
import '../models/attendance_query.dart';
import 'api_service.dart';

class AttendanceService {
  AttendanceService(this._api);

  final ApiService _api;

  Future<AttendanceToday> today() async {
    final body = await _api.get('${ApiConstants.attendance}/today');
    return AttendanceToday.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<AttendanceRecord> checkIn() async => _unwrap(await _api.post('${ApiConstants.attendance}/check-in'));

  Future<AttendanceRecord> checkOut() async => _unwrap(await _api.post('${ApiConstants.attendance}/check-out'));

  Future<AttendanceHistory> list(AttendanceQuery query) async {
    final body = await _api.get(ApiConstants.attendance, query: query.toQueryParameters());
    return AttendanceHistory.fromJson(body['data'] as Map<String, dynamic>);
  }

  AttendanceRecord _unwrap(Map<String, dynamic> body) =>
      AttendanceRecord.fromJson((body['data'] as Map<String, dynamic>)['attendance'] as Map<String, dynamic>);
}
