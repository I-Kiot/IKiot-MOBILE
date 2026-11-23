/// Sự kiện `entity:changed` của BE (`EntityChangedPayload`, `src/common/realtime/change-feed.types.ts`).
///
/// Chỉ là tín hiệu "có gì vừa đổi": mã chứng từ, người làm, động từ. Không bao giờ có tiền hay tên khách,
/// vì cả phòng của shop đều nhận. Màn nào thấy liên quan thì tự gọi lại API bằng quyền của mình.
class ChangeEvent {
  const ChangeEvent({
    required this.eventId,
    required this.action,
    required this.changes,
    required this.summary,
    required this.quiet,
    this.subjectCode,
  });

  final String eventId;
  final String action;

  /// Bảng → các id bị đổi. Danh sách rỗng nghĩa là "có dòng của bảng này đổi, không rõ dòng nào".
  final Map<String, List<String>> changes;

  /// Câu tiếng Việt hoàn chỉnh, hiện nguyên văn (vd. "An vừa giao thành công đơn DH000127").
  final String summary;

  /// Chỉ tải lại, không báo cho người dùng.
  final bool quiet;
  final String? subjectCode;

  bool touchesResource(String resource) => changes.containsKey(resource);

  /// Có chạm tới đúng id này của bảng này không.
  bool touchesId(String resource, String? id) =>
      id != null && (changes[resource]?.contains(id) ?? false);

  /// Có chạm tới một trong các id này không.
  bool touchesAny(String resource, Iterable<String> ids) {
    final changed = changes[resource];
    if (changed == null || changed.isEmpty) return false;
    return ids.any(changed.contains);
  }

  /// `null` khi payload không đúng hình dạng: bỏ qua sự kiện thay vì làm app lỗi.
  static ChangeEvent? tryParse(Object? data) {
    if (data is! Map) return null;
    final eventId = data['eventId'];
    final action = data['action'];
    final changes = data['changes'];
    if (eventId is! String || action is! String || changes is! List) {
      return null;
    }
    final parsed = <String, List<String>>{};
    for (final change in changes) {
      if (change is! Map || change['resource'] is! String) continue;
      final ids = change['ids'];
      parsed[change['resource'] as String] = ids is List
          ? ids.whereType<String>().toList()
          : const [];
    }
    final subject = data['subject'];
    return ChangeEvent(
      eventId: eventId,
      action: action,
      changes: parsed,
      summary: (data['summary'] as String?) ?? '',
      quiet: data['quiet'] == true,
      subjectCode: subject is Map ? subject['code'] as String? : null,
    );
  }
}

/// Tên bảng trong `changes`, như `ChangeResource` của BE.
abstract final class ChangeResource {
  static const orders = 'orders';
  static const shipments = 'shipments';
}
