/// Thông tin một lần gửi mã OTP qua email: cả thử thách lẫn "gửi lại mã" đều trả về (`OtpDelivery` của BE).
class OtpDelivery {
  const OtpDelivery({
    required this.sentTo,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
  });

  /// Email đã che bớt, vd. `ng***@gmail.com`.
  final String sentTo;
  final int expiresInSeconds;
  final int resendAfterSeconds;

  factory OtpDelivery.fromJson(Map<String, dynamic> json) => OtpDelivery(
    sentTo: (json['sentTo'] as String?) ?? '',
    expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 300,
    resendAfterSeconds: (json['resendAfterSeconds'] as num?)?.toInt() ?? 60,
  );
}

/// BE trả cái này thay cho phiên đăng nhập khi phải nhập mã OTP trước: đăng nhập lần đầu của tài khoản chưa xác minh
/// email, hoặc quên mật khẩu. `challengeToken` đổi lấy phiên (hoặc mã đặt lại mật khẩu) cùng với mã OTP.
class OtpChallenge {
  const OtpChallenge({required this.challengeToken, required this.delivery});

  final String challengeToken;
  final OtpDelivery delivery;

  /// `null` khi body không phải thử thách (`requiresOtp != true`), tức là đăng nhập đã cấp phiên.
  static OtpChallenge? tryParse(Map<String, dynamic> json) {
    final token = json['challengeToken'];
    if (json['requiresOtp'] != true || token is! String) return null;
    return OtpChallenge(
      challengeToken: token,
      delivery: OtpDelivery.fromJson(json),
    );
  }
}
