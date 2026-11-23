import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import 'shipment_summary.dart';

/// Nhãn trạng thái, cùng chữ với `SHIPMENT_STATUS_LABELS` của IKiot-FE.
String shipmentStatusLabel(String status) => switch (status) {
  ShipmentStatus.created => 'Chờ lấy hàng',
  ShipmentStatus.pickedUp => 'Chờ kho xuất hàng',
  ShipmentStatus.inTransit => 'Đang vận chuyển',
  ShipmentStatus.outForDelivery => 'Đang đi giao',
  ShipmentStatus.delivered => 'Đã giao',
  ShipmentStatus.failed => 'Giao không thành',
  ShipmentStatus.returned => 'Đã hoàn hàng',
  ShipmentStatus.cancelled => 'Đã huỷ',
  _ => status,
};

class ShipmentStatusBadge extends StatelessWidget {
  const ShipmentStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => FBadge(
    variant: switch (status) {
      ShipmentStatus.failed => FBadgeVariant.destructive,
      ShipmentStatus.delivered => FBadgeVariant.primary,
      ShipmentStatus.created ||
      ShipmentStatus.pickedUp => FBadgeVariant.outline,
      _ => FBadgeVariant.secondary,
    },
    child: Text(shipmentStatusLabel(status)),
  );
}

/// "Còn phải thu" như `amountDueText` của FE: số tiền, "Đã thu" sau khi giao, "Không phải thu" khi đã trả đủ từ trước.
String amountDueText(String status, num amountDue) {
  if (amountDue > 0) return formatMoney(amountDue);
  return status == ShipmentStatus.delivered ? 'Đã thu' : 'Không phải thu';
}

Future<void> callPhone(String phone) =>
    launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s'), '')));

/// Mở chỉ đường tới địa chỉ bằng Google Maps. Link https mở app Google Maps nếu máy có, không thì trình duyệt.
Future<void> openDirections(String address) => launchUrl(
  Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': address,
  }),
  mode: LaunchMode.externalApplication,
);
