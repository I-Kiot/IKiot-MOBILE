import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import 'auth_repository.dart';
import 'session_user.dart';

enum AuthStatus { unknown, signedIn, signedOut }

/// Trạng thái đăng nhập của cả app. Router nghe nó để chuyển giữa màn đăng nhập và các tab.
class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.unknown;
  SessionUser? _user;

  AuthStatus get status => _status;
  SessionUser? get user => _user;

  /// Chạy một lần lúc mở app. Có token thì thử `/auth/me`; mất mạng thì vẫn cho vào app
  /// (token còn đó, màn sẽ tự tải lại) thay vì đá người dùng ra màn đăng nhập.
  Future<void> restore() async {
    if (!await _repository.hasSession()) return _set(AuthStatus.signedOut);
    try {
      _user = await _repository.me();
      _set(AuthStatus.signedIn);
    } on ApiException catch (error) {
      _set(error.isNetwork ? AuthStatus.signedIn : AuthStatus.signedOut);
    }
  }

  /// Ném [ApiException] khi sai thông tin, để màn đăng nhập hiện lỗi.
  Future<void> login({
    required String phoneNumber,
    required String password,
  }) async {
    await _repository.login(phoneNumber: phoneNumber, password: password);
    try {
      _user = await _repository.me();
    } on ApiException {
      // Đã có token; hồ sơ tải lại sau ở màn Tôi.
    }
    _set(AuthStatus.signedIn);
  }

  /// Tải ảnh lên rồi đặt làm ảnh đại diện. Ném [ApiException] khi tải hoặc lưu thất bại;
  /// khi đó ảnh cũ vẫn giữ nguyên, vì chỉ đổi sau khi cả hai bước xong.
  Future<void> changeAvatar(String filePath) async {
    final url = await _repository.uploadImage(filePath);
    await _repository.setAvatar(url);
    await refreshUser();
  }

  Future<void> removeAvatar() async {
    await _repository.setAvatar(null);
    await refreshUser();
  }

  Future<void> refreshUser() async {
    _user = await _repository.me();
    notifyListeners();
  }

  /// Đổi xong thì xoá phiên ở máy: BE đã thu hồi refresh token này, giữ lại chỉ làm lần làm mới sau thất bại.
  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    await _repository.changePassword(current: current, next: next);
    await _repository.logout();
    _user = null;
    _set(AuthStatus.signedOut);
  }

  Future<void> logout() async {
    await _repository.logout();
    _user = null;
    _set(AuthStatus.signedOut);
  }

  /// [ApiClient] gọi khi refresh token bị từ chối.
  void sessionExpired() {
    if (_status == AuthStatus.signedOut) return;
    _user = null;
    _set(AuthStatus.signedOut);
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
