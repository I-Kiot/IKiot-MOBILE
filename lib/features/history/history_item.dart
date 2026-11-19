import '../deliveries/shipment_summary.dart';

/// Một dòng Lịch sử (`GET /shipments/mine/history`): tóm tắt lần giao + khoản mình đã thu.
class HistoryItem {
  const HistoryItem({
    required this.summary,
    required this.finishedAt,
    this.collection,
  });

  final ShipmentSummary summary;

  /// Lúc giao xong, hoặc lần cập nhật cuối với lần không giao được. BE lọc khoảng ngày theo đúng mốc này.
  final DateTime finishedAt;
  final Collection? collection;

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final delivered = json['deliveredAt'] as String?;
    final collection = json['collection'];
    return HistoryItem(
      summary: ShipmentSummary.fromJson(json),
      finishedAt: DateTime.parse(delivered ?? json['updatedAt'] as String)
          .toLocal(),
      collection: collection is Map<String, dynamic>
          ? Collection.fromJson(collection)
          : null,
    );
  }
}

/// Khoản mình thu lúc giao: `method` là `CASH` hoặc `SEPAY`, `status` `PAID` hoặc `PENDING` (QR chưa về).
class Collection {
  const Collection({
    required this.method,
    required this.amount,
    required this.status,
  });

  final String method;
  final num amount;
  final String status;

  String get methodLabel => method == 'CASH' ? 'Tiền mặt' : 'QR';
  bool get pending => status == 'PENDING';

  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
    method: json['method'] as String,
    amount: json['amount'] as num,
    status: json['status'] as String,
  );
}

/// Số liệu đầu màn, BE tính theo khoảng ngày (bỏ qua bộ lọc trạng thái và từ khoá).
class HistorySummary {
  const HistorySummary({
    this.active = 0,
    this.delivered = 0,
    this.failed = 0,
    this.collectedTotal = 0,
  });

  final int active;
  final int delivered;
  final int failed;

  /// Tiền mình đã thu thật (khoản đã về), không gồm QR còn chờ.
  final num collectedTotal;

  factory HistorySummary.fromJson(Map<String, dynamic>? json) => json == null
      ? const HistorySummary()
      : HistorySummary(
          active: (json['active'] as num?)?.toInt() ?? 0,
          delivered: (json['delivered'] as num?)?.toInt() ?? 0,
          failed: (json['failed'] as num?)?.toInt() ?? 0,
          collectedTotal: (json['collectedTotal'] as num?) ?? 0,
        );
}

/// Khoảng ngày chọn nhanh ở đầu màn.
enum HistoryRange { today, last7Days, thisMonth }

extension HistoryRangeDates on HistoryRange {
  String get label => switch (this) {
    HistoryRange.today => 'Hôm nay',
    HistoryRange.last7Days => '7 ngày',
    HistoryRange.thisMonth => 'Tháng này',
  };

  /// `(from, to)` dạng `YYYY-MM-DD`, cả hai đầu tính trọn ngày. Lấy theo lịch của máy;
  /// BE đọc như giờ Việt Nam, khớp khi điện thoại để múi giờ Việt Nam.
  (String, String) dates(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final from = switch (this) {
      HistoryRange.today => today,
      HistoryRange.last7Days => today.subtract(const Duration(days: 6)),
      HistoryRange.thisMonth => DateTime(now.year, now.month),
    };
    return (_ymd(from), _ymd(today));
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
