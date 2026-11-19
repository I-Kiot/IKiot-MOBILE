import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import 'session_user.dart';

class AuthRepository {
  AuthRepository({required this._api, required this._tokens});

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<bool> hasSession() async => await _tokens.readRefresh() != null;

  Future<void> login({
    required String phoneNumber,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/login',
      body: {'phoneNumber': phoneNumber, 'password': password},
    ) as Map<String, dynamic>;
    await _tokens.save(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  /// Tải ảnh lên `/uploads` rồi trả URL.
  Future<String> uploadImage(String filePath) async {
    final data =
        await _api.upload('/uploads', filePath) as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Đặt ảnh đại diện; `null` là xoá. Đây là trường duy nhất BE cho STAFF tự sửa (`AuthService.updateMe`).
  /// Gửi `null` tường minh, không bỏ khoá: bỏ khoá thì BE hiểu là "không đổi".
  Future<void> setAvatar(String? url) =>
      _api.patch('/auth/me', body: {'avatarUrl': url});

  Future<SessionUser> me() async =>
      SessionUser.fromJson(await _api.get('/auth/me') as Map<String, dynamic>);

  /// Đổi mật khẩu. BE thu hồi **mọi** phiên của tài khoản, kể cả phiên đang dùng, nên sau đó phải đăng nhập lại.
  Future<void> changePassword({
    required String current,
    required String next,
  }) => _api.post(
    '/auth/change-password',
    body: {
      'currentPassword': current,
      'newPassword': next,
      'reEnterPassword': next,
    },
  );

  /// Kết thúc phiên trên BE rồi mới xoá token. BE lỗi hay mất mạng thì vẫn xoá token ở máy:
  /// người dùng bấm đăng xuất thì máy này phải thoát, dù BE có nghe được hay không.
  Future<void> logout() async {
    try {
      final refreshToken = await _tokens.readRefresh();
      await _api.post('/auth/logout', body: {'refreshToken': ?refreshToken});
    } catch (_) {
      // Bỏ qua có chủ đích, xem chú thích trên.
    } finally {
      await _tokens.clear();
    }
  }
}
