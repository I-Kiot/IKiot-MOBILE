/// Người đang đăng nhập, đọc từ `GET /auth/me` (hoặc `user` trong phản hồi đăng nhập).
///
/// Người trong payload của BE luôn có dạng `{ id, phoneNumber, profile: { firstName, lastName } }`.
class SessionUser {
  const SessionUser({
    required this.id,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.email,
    this.locationName,
    this.roleName,
    this.systemRole,
    this.permissions = const {},
  });

  final String id;
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? email;

  /// Chi nhánh hoặc kho đang làm (`user.location.name`).
  final String? locationName;
  final String? roleName;
  final String? systemRole;

  /// Dạng `"resource:action"`. Chỉ `/auth/me` trả về; phản hồi đăng nhập thì rỗng.
  final Set<String> permissions;

  /// Được dùng app giao hàng không. **Cùng luật với `eligibleDriverWhere` của BE** (ai được gán làm shipper):
  /// chủ shop, hoặc STAFF có `shipments:deliver` trong role. Quyền tạm của trưởng ca không có `shipments`, nên
  /// không làm luật này đổi theo giờ ca. Người phụ trách đơn được gán giao đơn của chính mình nhưng không có quyền
  /// này thì vẫn bị chặn: app chỉ dành cho shipper.
  bool get canUseDeliveryApp =>
      systemRole == 'TENANT_OWNER' ||
      (systemRole == 'STAFF' && permissions.contains('shipments:deliver'));

  String get fullName {
    final name = '$lastName $firstName'.trim();
    return name.isEmpty ? phoneNumber : name;
  }

  String get initials {
    // Chỉ lấy từ bắt đầu bằng chữ cái: tên kiểu "Nguyễn Hoàng Hải (Shipper)" không được ra "H(".
    final startsWithLetter = RegExp(r'^\p{L}', unicode: true);
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where(startsWithLetter.hasMatch)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length < 2 ? 1 : 2)
          .toUpperCase();
    }
    return (parts[parts.length - 2][0] + parts.last[0]).toUpperCase();
  }

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map<String, dynamic>?) ?? const {};
    final role = json['role'] as Map<String, dynamic>?;
    final location = json['location'] as Map<String, dynamic>?;
    final permissions = json['permissions'];
    return SessionUser(
      id: json['id'] as String,
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      firstName: (profile['firstName'] as String?) ?? '',
      lastName: (profile['lastName'] as String?) ?? '',
      avatarUrl: profile['avatarUrl'] as String?,
      email: json['email'] as String?,
      locationName: location?['name'] as String?,
      roleName: role?['name'] as String?,
      systemRole: json['systemRole'] as String?,
      permissions: permissions is List
          ? permissions.whereType<String>().toSet()
          : const {},
    );
  }
}
