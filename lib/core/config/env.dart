import 'package:flutter/foundation.dart';

/// Địa chỉ IKiot-BE. Ghi đè bằng `--dart-define=API_BASE_URL=https://...` khi build bản thật.
///
/// Mặc định trỏ về BE chạy trên máy dev: máy ảo Android thấy máy chủ ở `10.0.2.2`,
/// máy ảo iOS dùng thẳng `localhost`. Máy thật thì phải truyền IP LAN qua dart-define.
abstract final class Env {
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3003';
    }
    return 'http://localhost:3003';
  }
}
