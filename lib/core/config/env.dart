import 'package:flutter/foundation.dart';

/// Địa chỉ IKiot-BE. Ghi đè bằng `--dart-define=API_BASE_URL=https://...` (vd. trỏ bản build sang API production).
///
/// - **Bản release** mặc định gọi BE đã host ([hostedApi]): một bản build quên `--dart-define` mà trỏ về `localhost`
///   thì cài lên máy thật không đăng nhập được, và lỗi đó chỉ lộ ra khi shipper đã cầm máy.
/// - **Bản debug / profile** mặc định gọi BE chạy trên máy dev: máy ảo Android thấy máy chủ ở `10.0.2.2`, máy ảo iOS
///   dùng thẳng `localhost`. Máy thật chạy debug thì truyền IP LAN qua dart-define.
abstract final class Env {
  static const _override = String.fromEnvironment('API_BASE_URL');

  /// Bước nhập mã OTP tự gửi `DEV_BYPASS` (BE chỉ nhận khi không chạy production), như `NEXT_PUBLIC_OTP_BYPASS` của
  /// IKiot-FE: thử trên máy ảo không cần hộp thư thật. `--dart-define=OTP_BYPASS=true`.
  static const otpBypass = bool.fromEnvironment('OTP_BYPASS');

  /// BE dev đã deploy. Đổi ở đây (hoặc truyền dart-define) khi có API production.
  static const hostedApi = 'https://api-dev.ikiot.io.vn';

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (kReleaseMode) return hostedApi;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3003';
    }
    return 'http://localhost:3003';
  }
}
