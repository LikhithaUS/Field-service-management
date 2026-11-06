import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fsm_app/core/exceptions/api_exception.dart';
import 'package:fsm_app/core/utils/validators.dart';
import 'package:fsm_app/models/user.dart';

void main() {
  group('User.fromJson', () {
    test('parses the backend user shape', () {
      final user = User.fromJson({
        'id': '665f1c',
        'name': 'Asha Rao',
        'email': 'asha@example.com',
        'role': 'manager',
        'isActive': true,
        'createdAt': '2026-11-06T10:00:00.000Z',
      });
      expect(user.id, '665f1c');
      expect(user.role, UserRole.manager);
      expect(user.firstName, 'Asha');
      expect(user.createdAt, DateTime.utc(2026, 11, 6, 10));
    });

    test('falls back to employee for unknown roles', () {
      final user = User.fromJson({'id': '1', 'name': 'X', 'email': 'x@y.z', 'role': 'superuser'});
      expect(user.role, UserRole.employee);
    });
  });

  group('ApiException.fromDio', () {
    final options = RequestOptions(path: '/auth/register');

    test('maps backend validation details to field errors', () {
      final e = ApiException.fromDio(DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: 400, data: {
          'success': false,
          'message': 'Validation failed',
          'details': [
            {'field': 'email', 'message': 'A valid email is required'},
            {'field': 'password', 'message': 'Password must be at least 8 characters'},
          ],
        }),
      ));
      expect(e.statusCode, 400);
      expect(e.message, 'Validation failed');
      expect(e.fieldErrors['email'], 'A valid email is required');
      expect(e.fieldErrors.length, 2);
    });

    test('uses the server message for 401', () {
      final e = ApiException.fromDio(DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: 401,
          data: {'success': false, 'message': 'Invalid email or password'},
        ),
      ));
      expect(e.isUnauthorized, isTrue);
      expect(e.message, 'Invalid email or password');
    });

    test('reports unreachable server as a network error', () {
      final e = ApiException.fromDio(
        DioException(requestOptions: options, type: DioExceptionType.connectionError),
      );
      expect(e.isNetworkError, isTrue);
      expect(e.message, contains('Cannot reach the server'));
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email('a@b.co'), isNull);
    });

    test('newPassword mirrors backend rules', () {
      expect(Validators.newPassword('short1'), contains('8 characters'));
      expect(Validators.newPassword('allletters'), contains('number'));
      expect(Validators.newPassword('12345678'), contains('letter'));
      expect(Validators.newPassword('secret123'), isNull);
    });
  });
}
