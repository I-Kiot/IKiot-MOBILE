/// Một trang của danh sách phân trang `{ data, pagination: { page, limit, total, totalPages } }`.
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
    this.raw = const {},
  });

  final List<T> items;
  final int page;
  final int totalPages;
  final int total;

  /// Phần còn lại của body (vd. `summary`, `unreadCount`), để mỗi màn tự đọc thêm.
  final Map<String, dynamic> raw;

  bool get hasMore => page < totalPages;

  factory Paged.fromJson(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) item,
  ) {
    final pagination =
        (body['pagination'] as Map<String, dynamic>?) ?? const {};
    return Paged(
      items: (body['data'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(item)
          .toList(),
      page: (pagination['page'] as num?)?.toInt() ?? 1,
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
      total: (pagination['total'] as num?)?.toInt() ?? 0,
      raw: body,
    );
  }
}
