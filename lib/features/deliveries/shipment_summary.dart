/// Một lần giao trong danh sách, từ `toSummary` của BE (`shipment-view.ts`).
class ShipmentSummary {
  const ShipmentSummary({
    required this.id,
    required this.status,
    required this.orderCode,
    required this.customerName,
    required this.amountDue,
    this.recipientName,
    this.recipientPhone,
    this.deliveryAddress,
    this.scheduledDate,
    this.scheduledSlot,
    this.requiresInstallation = false,
  });

  final String id;
  final String status;
  final String orderCode;
  final String customerName;

  /// Số còn phải thu lúc xem, BE đã trừ cọc và mọi khoản đã trả. 0 là đã trả đủ.
  final num amountDue;
  final String? recipientName;
  final String? recipientPhone;
  final String? deliveryAddress;
  final DateTime? scheduledDate;
  final String? scheduledSlot;
  final bool requiresInstallation;

  /// Tên hiện ở dòng đầu: người nhận nếu có, không thì khách của đơn.
  String get displayName => (recipientName?.trim().isNotEmpty ?? false)
      ? recipientName!
      : customerName;

  /// Chưa lấy hàng ở kho (wireframe nhóm "Chờ lấy hàng").
  bool get awaitingPickUp => status == ShipmentStatus.created;

  factory ShipmentSummary.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>;
    final date = json['scheduledDate'] as String?;
    return ShipmentSummary(
      id: json['id'] as String,
      status: json['status'] as String,
      orderCode: (order['code'] as String?) ?? '',
      customerName: (order['customerName'] as String?) ?? '',
      amountDue: (order['amountDue'] as num?) ?? 0,
      recipientName: json['recipientName'] as String?,
      recipientPhone: json['recipientPhone'] as String?,
      deliveryAddress: json['deliveryAddress'] as String?,
      scheduledDate: date == null ? null : DateTime.parse(date),
      scheduledSlot: json['scheduledSlot'] as String?,
      requiresInstallation: (json['requiresInstallation'] as bool?) ?? false,
    );
  }
}

/// Trạng thái shipment, cùng giá trị với `shipment-status.ts` của BE.
abstract final class ShipmentStatus {
  static const created = 'CREATED';
  static const pickedUp = 'PICKED_UP';
  static const inTransit = 'IN_TRANSIT';
  static const outForDelivery = 'OUT_FOR_DELIVERY';
  static const delivered = 'DELIVERED';
  static const failed = 'FAILED';
  static const returned = 'RETURNED';
  static const cancelled = 'CANCELLED';
}
