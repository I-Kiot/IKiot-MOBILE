import 'package:dio/dio.dart';

/// Lỗi từ IKiot-BE, đọc từ envelope `{ success: false, statusCode, code, message }`.
///
/// Màn hình rẽ nhánh theo [code], không theo [message]: message của BE là tiếng Anh cho log
/// và có thể bị viết lại bất cứ lúc nào (xem "Error codes" trong CLAUDE.md của BE).
class ApiException implements Exception {
  const ApiException({required this.statusCode, this.code, this.message});

  /// `null` khi không tới được máy chủ (mất mạng, sai địa chỉ, quá thời gian chờ).
  final int? statusCode;
  final String? code;
  final String? message;

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

  /// Câu hiển thị cho người dùng, chép từ `error-codes.ts` của IKiot-FE để hai nơi nói giống nhau.
  /// Mã nào màn hình cần nói riêng thì thêm vào đây.
  String get userMessage {
    if (isNetwork) {
      return 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.';
    }
    return switch (code) {
      'INVALID_CREDENTIALS' => 'Số điện thoại hoặc mật khẩu không đúng.',
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
