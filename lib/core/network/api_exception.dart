import 'package:dio/dio.dart';

/// Lỗi từ IKiot-BE, đọc từ envelope `{ success: false, statusCode, code, message }`.
///
/// Màn hình rẽ nhánh theo [code], không theo [message]: message của BE là tiếng Anh cho log
/// và có thể bị viết lại bất cứ lúc nào (xem "Error codes" trong CLAUDE.md của BE).
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    this.code,
    this.message,
    this.attemptsLeft,
    this.retryAfterSeconds,
  });

  /// Lỗi sinh ở máy, không phải từ BE: tài khoản đăng nhập đúng nhưng không được dùng app (xem `canUseDeliveryApp`).
  static const deliveryOnlyCode = 'LOGIN_MOBILE_DELIVERY_ONLY';

  /// `null` khi không tới được máy chủ (mất mạng, sai địa chỉ, quá thời gian chờ).
  final int? statusCode;
  final String? code;
  final String? message;

  /// `OTP_INVALID`: số lần nhập còn lại trước khi mã bị huỷ.
  final int? attemptsLeft;

  /// `OTP_RESEND_TOO_SOON`: số giây phải đợi để gửi lại mã.
  final int? retryAfterSeconds;

  bool get isNetwork => statusCode == null;

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) return const ApiException(statusCode: null);
    final body = response.data;
    if (body is Map<String, dynamic>) {
      final message = body['message'];
      return ApiException(
        statusCode: response.statusCode,
        code: body['code'] as String?,
        message: message is String ? message : null,
        attemptsLeft: (body['attemptsLeft'] as num?)?.toInt(),
        retryAfterSeconds: (body['retryAfterSeconds'] as num?)?.toInt(),
      );
    }
    return ApiException(statusCode: response.statusCode);
  }

  /// Dữ liệu trên màn đã cũ (người khác vừa đổi đơn / lần giao, tiền vừa về): phải tải lại.
  /// Cùng tập mã với `STALE_CODES` của IKiot-FE (`shipment-ui.tsx`).
  bool get isStale => _staleCodes.contains(code);

  static const _staleCodes = {
    'ORDER_STATUS_CONFLICT',
    'ORDER_STATUS_TRANSITION_INVALID',
    'SHIPMENT_STATUS_INVALID',
    'SHIPMENT_ORDER_NOT_PACKED',
    'SHIPMENT_ORDER_NOT_SHIPPING',
    'SHIPMENT_FULFILLMENT_NOT_HANDED_OVER',
    'ORDER_QR_PAYMENT_NOT_PENDING',
    'ORDER_COLLECTION_AMOUNT_MISMATCH',
  };

  /// Phiên xác minh OTP không dùng tiếp được nữa: phải quay lại bước trước (như `OtpStep` của IKiot-FE).
  bool get isOtpChallengeDead => code == 'OTP_CHALLENGE_INVALID';

  /// Mã đặt lại mật khẩu hết hạn / đã dùng: phải xin mã OTP mới từ đầu.
  bool get isResetTokenDead => const {
    'RESET_TOKEN_INVALID',
    'RESET_TOKEN_USED',
    'RESET_TOKEN_WRONG_TYPE',
  }.contains(code);

  /// Câu hiển thị cho người dùng, chép từ `error-codes.ts` của IKiot-FE để hai nơi nói giống nhau.
  /// Mã nào màn hình cần nói riêng thì thêm vào đây.
  String get userMessage {
    if (isNetwork) {
      return 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.';
    }
    return switch (code) {
      'INVALID_CREDENTIALS' =>
        'Số điện thoại / email hoặc mật khẩu không đúng.',
      deliveryOnlyCode =>
        'Tài khoản không có quyền giao hàng nên không dùng được ứng dụng này. '
            'Liên hệ quản lý cửa hàng nếu bạn cần giao hàng.',
      'ACCOUNT_EMAIL_MISSING' =>
        'Tài khoản chưa có email nên chưa gửi được mã xác minh. '
            'Nhờ quản lý cập nhật email cho tài khoản.',
      'ACCOUNT_INACTIVE' => 'Tài khoản đã bị khoá hoặc chưa kích hoạt.',
      'ACCOUNT_NOT_FOUND_OR_LOCKED' =>
        'Tài khoản không tồn tại hoặc đã bị khoá.',
      'PHONE_REQUIRED' => 'Nhập số điện thoại hoặc email.',
      'PHONE_NOT_REGISTERED' => 'Số điện thoại hoặc email chưa được đăng ký, hoặc tài khoản đã bị khoá.',
      'OTP_INVALID' => 'Mã OTP không đúng.',
      'OTP_EXPIRED' => 'Mã OTP đã hết hạn hoặc chưa được gửi. Gửi lại mã mới.',
      'OTP_CHALLENGE_INVALID' =>
        'Phiên xác minh không còn hợp lệ. Thử lại từ đầu.',
      'OTP_RESEND_TOO_SOON' => 'Bạn vừa yêu cầu mã, đợi một lúc rồi gửi lại.',
      'OTP_TOO_MANY_ATTEMPTS' => 'Nhập sai quá nhiều lần. Gửi lại mã mới.',
      'OTP_SEND_FAILED' =>
        'Không gửi được mã OTP qua email. Thử lại sau ít phút.',
      'EMAIL_NOT_CONFIGURED' => 'Máy chủ chưa cấu hình gửi email.',
      'RESET_TOKEN_INVALID' || 'RESET_TOKEN_WRONG_TYPE' =>
        'Phiên đặt lại mật khẩu đã hết hạn. Làm lại từ đầu.',
      'RESET_TOKEN_USED' =>
        'Phiên đặt lại mật khẩu đã được dùng. Làm lại từ đầu.',
      'VALIDATION_FAILED' => 'Thông tin chưa hợp lệ, kiểm tra lại.',
      'ORDER_STATUS_CONFLICT' || 'ORDER_STATUS_TRANSITION_INVALID' =>
        'Trạng thái đơn vừa thay đổi, đã tải lại.',
      'SHIPMENT_STATUS_INVALID' => 'Lần giao vừa thay đổi, đã tải lại.',
      'SHIPMENT_ORDER_NOT_SHIPPING' =>
        'Kho chưa xác nhận xuất hàng, chưa giao được.',
      'SHIPMENT_NOT_ASSIGNED' => 'Bạn không còn là người giao đơn này.',
      'SHIPMENT_NOT_FOUND' => 'Không tìm thấy lần giao hàng.',
      'SHIPMENT_PROOF_REQUIRED' => 'Cần ít nhất một ảnh giao hàng.',
      'SHIPMENT_DELIVER_INTERNAL_ONLY' =>
        'Đơn giao qua đơn vị vận chuyển ngoài, không xác nhận tay được.',
      'ORDER_COLLECTION_AMOUNT_MISMATCH' =>
        'Số còn phải thu vừa thay đổi, đã tải lại.',
      'ORDER_QR_PAYMENT_NOT_PENDING' =>
        'Khoản QR không còn chờ, có thể khách vừa chuyển xong.',
      'TENANT_BANKING_NOT_CONFIGURED' || 'TENANT_SEPAY_NOT_LINKED' =>
        'Cửa hàng chưa bật nhận tiền bằng QR. Thu tiền mặt.',
      'CURRENT_PASSWORD_INCORRECT' => 'Mật khẩu hiện tại không đúng.',
      'PASSWORD_CONFIRMATION_MISMATCH' => 'Mật khẩu nhập lại không khớp.',
      'PASSWORD_NOT_SET' => 'Tài khoản chưa có mật khẩu. Liên hệ cửa hàng.',
      'UPLOAD_FILE_TOO_LARGE' => 'Ảnh vượt quá 5MB.',
      'UPLOAD_FORMAT_UNSUPPORTED' => 'Định dạng ảnh không được hỗ trợ.',
      'UPLOAD_NOT_CONFIGURED' || 'UPLOAD_FAILED' => 'Tải ảnh lên thất bại.',
      _ when statusCode == 401 => 'Phiên đăng nhập đã hết, đăng nhập lại.',
      _ when statusCode == 403 => 'Bạn không có quyền làm việc này.',
      _ when statusCode == 404 => 'Không tìm thấy dữ liệu.',
      _ => 'Có lỗi xảy ra, thử lại sau.',
    };
  }

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}
