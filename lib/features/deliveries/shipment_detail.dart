import 'shipment_summary.dart';

/// Chi tiết một lần giao, từ `loadShipmentDetail` của BE: phần tóm tắt + nhật trình + khoản QR.
class ShipmentDetail {
  const ShipmentDetail({
    required this.summary,
    required this.orderStatus,
    required this.carrierType,
    this.note,
    this.deliveredAt,
    this.events = const [],
    this.payment,
  });

  final ShipmentSummary summary;
  final String orderStatus;

  /// `INTERNAL` (shipper của shop) | `EXTERNAL` (đơn vị vận chuyển). Chỉ INTERNAL xác nhận tay được.
  final String carrierType;
  final String? note;
  final DateTime? deliveredAt;
  final List<ShipmentEvent> events;
  final QrPayment? payment;

  String get id => summary.id;
  String get status => summary.status;
  num get amountDue => summary.amountDue;

  /// Đang trên đường: giao được, báo không thành được (trừ khi đã FAILED). Như `isOnTheRoad` của FE.
  bool get onTheRoad => const {
    ShipmentStatus.inTransit,
    ShipmentStatus.outForDelivery,
    ShipmentStatus.failed,
  }.contains(status);

  /// Đã giao bằng QR nhưng tiền chưa đủ: còn mã đang chờ / đã hết hạn, hoặc khách chuyển thiếu.
  bool get awaitingQrMoney {
    final p = payment;
    if (status != ShipmentStatus.delivered || p == null) return false;
    return p.status == QrPaymentStatus.pending ||
        p.status == QrPaymentStatus.expired ||
        (p.status == QrPaymentStatus.paid && amountDue > 0);
  }

  factory ShipmentDetail.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>;
    final events = json['events'];
    final payment = json['payment'];
    final deliveredAt = json['deliveredAt'] as String?;
    return ShipmentDetail(
      summary: ShipmentSummary.fromJson(json),
      orderStatus: (order['status'] as String?) ?? '',
      carrierType: (json['carrierType'] as String?) ?? 'INTERNAL',
      note: json['note'] as String?,
      deliveredAt: deliveredAt == null
          ? null
          : DateTime.parse(deliveredAt).toLocal(),
      events: events is List
          ? events
                .cast<Map<String, dynamic>>()
                .map(ShipmentEvent.fromJson)
                .toList()
          : const [],
      payment: payment is Map<String, dynamic>
          ? QrPayment.fromJson(payment)
          : null,
    );
  }
}

class ShipmentEvent {
  const ShipmentEvent({
    required this.status,
    required this.occurredAt,
    this.note,
  });

  final String status;
  final DateTime occurredAt;
  final String? note;

  factory ShipmentEvent.fromJson(Map<String, dynamic> json) => ShipmentEvent(
    status: json['status'] as String,
    occurredAt: DateTime.parse(
      (json['occurredAt'] ?? json['createdAt']) as String,
    ).toLocal(),
    note: json['note'] as String?,
  );
}

/// Khoản thu QR lúc giao (`ShipmentQrPayment` của BE). `qrUrl` là ảnh VietQR, chỉ có khi còn chờ và còn hạn.
class QrPayment {
  const QrPayment({
    required this.reference,
    required this.amount,
    required this.status,
    required this.expiresAt,
    required this.expired,
    this.qrUrl,
  });

  final String reference;
  final num amount;
  final String status;
  final String? qrUrl;
  final DateTime expiresAt;
  final bool expired;

  factory QrPayment.fromJson(Map<String, dynamic> json) => QrPayment(
    reference: json['reference'] as String,
    amount: json['amount'] as num,
    status: json['status'] as String,
    qrUrl: json['qrUrl'] as String?,
    expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
    expired: (json['expired'] as bool?) ?? false,
  );
}

abstract final class QrPaymentStatus {
  static const pending = 'PENDING';
  static const paid = 'PAID';
  static const expired = 'EXPIRED';
}

/// Cách thu tiền lúc giao, như `DELIVERY_COLLECTION_METHODS` của BE.
abstract final class CollectionMethod {
  static const cash = 'CASH';
  static const qr = 'BANK_TRANSFER_QR';

  /// Đơn đã trả đủ từ trước, không thu gì.
  static const none = 'NONE';
}
