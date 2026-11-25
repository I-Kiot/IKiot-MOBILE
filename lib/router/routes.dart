/// Đường dẫn của mọi màn. Push thông báo và deep link dùng các hằng này, không gõ chuỗi tay.
abstract final class Routes {
  static const splash = '/';
  static const login = '/login';

  /// Quên mật khẩu, đẩy lên trên màn đăng nhập. `extra` là ô số điện thoại / email đang gõ dở.
  static const forgotPassword = '/login/forgot';
  static const deliveries = '/deliveries';
  static const history = '/history';
  static const profile = '/me';
  static const notifications = '/notifications';
  static const personalInfo = '/me/info';
  static const changePassword = '/me/password';

  /// Chi tiết một lần giao. Push "được giao đơn" mở thẳng vào đây.
  static String delivery(String id) => '/deliveries/$id';

  /// Màn mã QR cho khách quét của một lần giao.
  static String deliveryQr(String id) => '/deliveries/$id/qr';
}
