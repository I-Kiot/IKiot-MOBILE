import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import 'auth_repository.dart';
import 'otp_challenge.dart';
import 'session_user.dart';

enum AuthStatus { unknown, signedIn, signedOut }

/// Trạng thái đăng nhập của cả app. Router nghe nó để chuyển giữa màn đăng nhập và các tab.
class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  /// Chạy trước khi xoá token phiên khi người dùng tự đăng xuất / đổi mật khẩu: việc cần gọi BE bằng phiên này
  /// (gỡ thiết bị nhận push). Lỗi bị nuốt, không được chặn việc đăng xuất.
  Future<void> Function()? beforeSignOut;

  Future<void> _runBeforeSignOut() async {
    try {
      await beforeSignOut?.call();
    } catch (_) {}
  }

  AuthStatus _status = AuthStatus.unknown;
  SessionUser? _user;

  AuthStatus get status => _status;
  SessionUser? get user => _user;

  /// Lý do bị đưa ra màn đăng nhập mà người dùng không tự bấm (vd. vừa bị gỡ quyền giao hàng). Màn đăng nhập đọc
  /// một lần qua [takeNotice].
  String? _notice;

  String? takeNotice() {
    final notice = _notice;
    _notice = null;
    return notice;
  }

  /// Chạy một lần lúc mở app. Có token thì thử `/auth/me`; mất mạng thì vẫn cho vào app
  /// (token còn đó, màn sẽ tự tải lại) thay vì đá người dùng ra màn đăng nhập.
  Future<void> restore() async {
    if (!await _repository.hasSession()) return _set(AuthStatus.signedOut);
    try {
      final user = await _repository.me();
      // Quyền được đọc lại mỗi lần mở app: bị gỡ quyền giao hàng từ lúc đăng nhập thì phải ra ngoài.
      if (!user.canUseDeliveryApp) {
        await _repository.logout();
        _notice = const ApiException(
          statusCode: 403,
          code: ApiException.deliveryOnlyCode,
        ).userMessage;
        return _set(AuthStatus.signedOut);
      }
      _user = user;
      _set(AuthStatus.signedIn);
    } on ApiException catch (error) {
      _set(error.isNetwork ? AuthStatus.signedIn : AuthStatus.signedOut);
    }
  }

  /// Bước 1 của đăng nhập. Trả [OtpChallenge] khi tài khoản chưa xác minh email: màn đăng nhập chuyển sang bước nhập
  /// mã rồi gọi [verifyLoginOtp]. Ném [ApiException] khi sai thông tin hoặc tài khoản không được dùng app.
  Future<OtpChallenge?> login({
    required String identifier,
    required String password,
  }) async {
    final challenge = await _repository.login(
      identifier: identifier,
      password: password,
    );
    if (challenge == null) await _enterSession();
    return challenge;
  }

  /// Bước 2 (chỉ khi BE đòi): mã OTP đúng thì BE xác minh email và cấp phiên.
  Future<void> verifyLoginOtp(String challengeToken, String otpCode) async {
    await _repository.verifyLoginOtp(challengeToken, otpCode);
    await _enterSession();
  }

  Future<OtpDelivery> resendOtp(String challengeToken) =>
      _repository.resendOtp(challengeToken);

  Future<OtpChallenge> sendForgotPasswordOtp(String identifier) =>
      _repository.sendForgotPasswordOtp(identifier);

  Future<String> verifyForgotPasswordOtp(
    String challengeToken,
    String otpCode,
  ) => _repository.verifyForgotPasswordOtp(challengeToken, otpCode);

  Future<void> resetPassword(String resetToken, String newPassword) =>
      _repository.resetPassword(resetToken, newPassword);

  /// Đã có token: đọc quyền rồi mới vào app. Người không có quyền giao hàng thì kết thúc phiên vừa cấp (thu hồi
  /// refresh token trên BE) và báo lỗi, không để lại phiên mồ côi. Không đọc được quyền thì cũng không vào: cổng
  /// này không được mở khi chưa biết.
  ///
  /// Chặn ở app chứ không ở BE: BE không có khái niệm "đăng nhập từ app giao hàng" ở `/auth/login`, và người không
  /// phải shipper có vào được cũng không thấy gì (`/shipments/mine` chỉ trả lần giao của chính họ).
  Future<void> _enterSession() async {
    final SessionUser user;
    try {
      user = await _repository.me();
    } on ApiException {
      await _repository.logout();
      rethrow;
    }
    if (!user.canUseDeliveryApp) {
      await _repository.logout();
      throw const ApiException(
        statusCode: 403,
        code: ApiException.deliveryOnlyCode,
      );
    }
    _user = user;
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
    // BE chỉ thu hồi refresh token; access token đang giữ vẫn dùng được cho lời gọi gỡ thiết bị.
    await _runBeforeSignOut();
    await _repository.logout();
    _user = null;
    _set(AuthStatus.signedOut);
  }

  Future<void> logout() async {
    await _runBeforeSignOut();
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
