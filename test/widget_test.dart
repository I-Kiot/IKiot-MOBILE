import 'package:flutter_test/flutter_test.dart';

import 'package:ikiot_mobile/features/auth/session_user.dart';
import 'package:ikiot_mobile/features/deliveries/fail_sheet.dart';
import 'package:ikiot_mobile/features/deliveries/shipment_detail.dart';
import 'package:ikiot_mobile/features/deliveries/shipment_summary.dart';

void main() {
  test('SessionUser đọc người theo dạng { profile: { firstName, lastName } } của BE', () {
    final user = SessionUser.fromJson({
      'id': 'u1',
      'phoneNumber': '0912345678',
      'systemRole': 'STAFF',
      'role': {'id': 'r1', 'name': 'Giao hàng'},
      'profile': {'firstName': 'Vinh', 'lastName': 'Đỗ Quang'},
      'permissions': ['shipments:deliver'],
    });
    expect(user.fullName, 'Đỗ Quang Vinh');
    expect(user.initials, 'QV');
    expect(user.roleName, 'Giao hàng');
    expect(user.permissions, contains('shipments:deliver'));
    final tagged = SessionUser.fromJson({
      'id': 'u2',
      'phoneNumber': '0901189804',
      'profile': {'firstName': 'Hải (Shipper)', 'lastName': 'Nguyễn Hoàng'},
    });
    expect(tagged.initials, 'HH');
  });

  test('ShipmentSummary ưu tiên tên người nhận, rơi về tên khách của đơn', () {
    final withRecipient = ShipmentSummary.fromJson({
      'id': 's1',
      'status': 'CREATED',
      'recipientName': 'Anh Khoa',
      'order': {'id': 'o1', 'code': 'DH000127', 'customerName': 'Nội Thất Phương Nam', 'amountDue': 8500000},
    });
    final withoutRecipient = ShipmentSummary.fromJson({
      'id': 's2',
      'status': 'OUT_FOR_DELIVERY',
      'order': {'code': 'DH000125', 'customerName': 'Trần Bảo Ngọc', 'amountDue': 0},
    });
    expect(withRecipient.displayName, 'Anh Khoa');
    expect(withRecipient.awaitingPickUp, isTrue);
    expect(withoutRecipient.displayName, 'Trần Bảo Ngọc');
    expect(withoutRecipient.amountDue, 0);
  });

  test('Lý do giao không thành ghép vào đầu ghi chú gửi BE', () {
    expect(composeFailNote(null, '  '), '');
    expect(composeFailNote('Sai địa chỉ', ''), 'Sai địa chỉ');
    expect(composeFailNote('Sai địa chỉ', ' số nhà 12 không có '), 'Sai địa chỉ: số nhà 12 không có');
    expect(composeFailNote(null, 'Khách đi vắng'), 'Khách đi vắng');
  });

  group('ShipmentDetail.awaitingQrMoney', () {
    Map<String, dynamic> detail({required String status, required num due, Map<String, dynamic>? payment}) => {
      'id': 's1',
      'status': status,
      'carrierType': 'INTERNAL',
      'order': {'code': 'DH1', 'status': 'RECEIVED', 'customerName': 'A', 'amountDue': due},
      'events': [],
      'payment': payment,
    };
    Map<String, dynamic> qr(String status) => {
      'reference': 'ORD1',
      'amount': 100,
      'status': status,
      'qrUrl': null,
      'expiresAt': '2026-11-19T10:00:00.000Z',
      'expired': false,
    };

    test('mã còn chờ hoặc hết hạn thì còn chờ tiền', () {
      expect(ShipmentDetail.fromJson(detail(status: 'DELIVERED', due: 100, payment: qr('PENDING'))).awaitingQrMoney, isTrue);
      expect(ShipmentDetail.fromJson(detail(status: 'DELIVERED', due: 100, payment: qr('EXPIRED'))).awaitingQrMoney, isTrue);
    });

    test('khách chuyển thiếu vẫn còn chờ, chuyển đủ thì xong', () {
      expect(ShipmentDetail.fromJson(detail(status: 'DELIVERED', due: 40, payment: qr('PAID'))).awaitingQrMoney, isTrue);
      expect(ShipmentDetail.fromJson(detail(status: 'DELIVERED', due: 0, payment: qr('PAID'))).awaitingQrMoney, isFalse);
    });

    test('chưa giao hoặc thu tiền mặt thì không có gì chờ', () {
      expect(ShipmentDetail.fromJson(detail(status: 'OUT_FOR_DELIVERY', due: 100, payment: qr('PENDING'))).awaitingQrMoney, isFalse);
      expect(ShipmentDetail.fromJson(detail(status: 'DELIVERED', due: 0)).awaitingQrMoney, isFalse);
    });
  });
}
