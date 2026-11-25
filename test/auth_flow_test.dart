import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikiot_mobile/core/network/api_exception.dart';
import 'package:ikiot_mobile/features/auth/otp_challenge.dart';
import 'package:ikiot_mobile/features/auth/session_user.dart';

SessionUser _user(String role, [List<String> permissions = const []]) =>
    SessionUser.fromJson({
      'id': 'u',
      'phoneNumber': '0900000000',
      'systemRole': role,
      'profile': {'firstName': 'A', 'lastName': 'B'},
      'permissions': permissions,
    });

void main() {
  group('canUseDeliveryApp (cùng luật eligibleDriverWhere của BE)', () {
    test('STAFF có shipments:deliver thì vào được', () {
      expect(
        _user('STAFF', ['profile:read', 'shipments:deliver']).canUseDeliveryApp,
        isTrue,
      );
    });

    test('STAFF không có shipments:deliver thì bị chặn', () {
      expect(
        _user('STAFF', [
          'profile:read',
          'shipments:read',
          'shipments:update',
          'orders:read',
        ]).canUseDeliveryApp,
        isFalse,
      );
    });

    test('chủ shop vào được dù /auth/me trả quyền rỗng', () {
      expect(_user('TENANT_OWNER').canUseDeliveryApp, isTrue);
    });

    test('ADMIN nền tảng và CUSTOMER bị chặn', () {
      expect(_user('ADMIN').canUseDeliveryApp, isFalse);
      expect(
        _user('CUSTOMER', ['shipments:deliver']).canUseDeliveryApp,
        isFalse,
      );
    });
  });

  group('OtpChallenge.tryParse', () {
    test('đọc thử thách của /auth/login khi email chưa xác minh', () {
      final challenge = OtpChallenge.tryParse({
        'requiresOtp': true,
        'challengeToken': 'tok',
        'sentTo': 'ng***@gmail.com',
        'expiresInSeconds': 300,
        'resendAfterSeconds': 60,
      });
      expect(challenge?.challengeToken, 'tok');
      expect(challenge?.delivery.sentTo, 'ng***@gmail.com');
      expect(challenge?.delivery.expiresInSeconds, 300);
      expect(challenge?.delivery.resendAfterSeconds, 60);
    });

    test('phản hồi có phiên thì không phải thử thách', () {
      expect(
        OtpChallenge.tryParse({
          'accessToken': 'a',
          'refreshToken': 'r',
          'user': {'id': 'u'},
        }),
        isNull,
      );
    });
  });

  group('ApiException với lỗi OTP', () {
    ApiException fromBody(int status, Map<String, dynamic> body) =>
        ApiException.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/auth/login/verify-otp'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/login/verify-otp'),
              statusCode: status,
              data: body,
            ),
          ),
        );

    test('OTP_INVALID mang số lần thử còn lại', () {
      final error = fromBody(400, {
        'success': false,
        'code': 'OTP_INVALID',
        'message': 'Invalid OTP code',
        'attemptsLeft': 3,
      });
      expect(error.attemptsLeft, 3);
      expect(error.userMessage, 'Mã OTP không đúng.');
      expect(error.isOtpChallengeDead, isFalse);
    });

    test('OTP_CHALLENGE_INVALID buộc quay lại bước trước', () {
      final error = fromBody(400, {'code': 'OTP_CHALLENGE_INVALID'});
      expect(error.isOtpChallengeDead, isTrue);
    });

    test('OTP_RESEND_TOO_SOON mang số giây phải đợi', () {
      final error = fromBody(429, {
        'code': 'OTP_RESEND_TOO_SOON',
        'retryAfterSeconds': 42,
      });
      expect(error.retryAfterSeconds, 42);
    });

    test('mã đặt lại mật khẩu hỏng thì làm lại từ đầu', () {
      for (final code in [
        'RESET_TOKEN_INVALID',
        'RESET_TOKEN_USED',
        'RESET_TOKEN_WRONG_TYPE',
      ]) {
        expect(fromBody(400, {'code': code}).isResetTokenDead, isTrue);
      }
    });

    test('lỗi chặn app giao hàng có câu riêng', () {
      const error = ApiException(
        statusCode: 403,
        code: ApiException.deliveryOnlyCode,
      );
      expect(error.userMessage, contains('không có quyền giao hàng'));
    });
  });
}
