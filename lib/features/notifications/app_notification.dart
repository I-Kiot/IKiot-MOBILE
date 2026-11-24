/// Một thông báo trong hộp thư (`Notification` của BE).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.isRead,
    required this.createdAt,
    this.link,
    this.referenceId,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final bool isRead;
  final DateTime createdAt;

  /// Đường dẫn của IKiot-FE, vd. `/shipments/<id>`. App không dùng thẳng được, xem [shipmentId].
  final String? link;
  final String? referenceId;

  /// Lần giao mà thông báo nói tới, để mở màn chi tiết. Thông báo giao hàng (`SHIPMENT_*`) mang id shipment
  /// trong `referenceId`; thông báo khác (đơn, tiền) trỏ vào màn của web, app không có màn tương ứng.
  String? get shipmentId =>
      shipmentIdOf(type: type, referenceId: referenceId, link: link);

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    description: description,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    link: link,
    referenceId: referenceId,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: (json['type'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        isRead: (json['isRead'] as bool?) ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        link: json['link'] as String?,
        referenceId: json['referenceId'] as String?,
      );
}

/// Một quy tắc cho cả hộp thông báo lẫn push (push mang `type` và `referenceId` trong `data`, không có `link`).
String? shipmentIdOf({String? type, String? referenceId, String? link}) {
  if ((type ?? '').startsWith('SHIPMENT_') &&
      referenceId != null &&
      referenceId.isNotEmpty) {
    return referenceId;
  }
  final match = RegExp(r'^/shipments/([0-9a-f-]{36})').firstMatch(link ?? '');
  return match?.group(1);
}
