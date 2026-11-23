import 'package:flutter_test/flutter_test.dart';

import 'package:ikiot_mobile/core/realtime/change_event.dart';

void main() {
  // Hình dạng thật của `entity:changed` khi tiền QR lúc giao về (webhook SePay, orders.controller.ts).
  final qrPaid = {
    'eventId': 'e1',
    'action': 'ORDER_QR_PAID',
    'changes': [
      {'resource': 'orders', 'ids': ['order-1']},
      {'resource': 'shipments', 'ids': <String>[]},
    ],
    'subject': {'resource': 'orders', 'id': 'order-1', 'code': 'DH000127'},
    'actor': {'id': null, 'name': 'SePay'},
    'source': 'WEBHOOK',
    'summary': 'Đơn DH000127 vừa được khách thanh toán qua SePay',
    'quiet': false,
    'at': '2026-11-23T03:00:00.000Z',
  };

  test('đọc đúng payload entity:changed', () {
    final event = ChangeEvent.tryParse(qrPaid)!;
    expect(event.action, 'ORDER_QR_PAID');
    expect(event.subjectCode, 'DH000127');
    expect(event.summary, contains('SePay'));
    expect(event.quiet, isFalse);
  });

  test('so khớp theo bảng và id', () {
    final event = ChangeEvent.tryParse(qrPaid)!;
    expect(event.touchesId(ChangeResource.orders, 'order-1'), isTrue);
    expect(event.touchesId(ChangeResource.orders, 'order-2'), isFalse);
    expect(event.touchesId(ChangeResource.orders, null), isFalse);
    // `shipments: []` = có lần giao đổi nhưng không rõ lần nào: chạm bảng, không chạm id cụ thể.
    expect(event.touchesResource(ChangeResource.shipments), isTrue);
    expect(event.touchesId(ChangeResource.shipments, 'ship-1'), isFalse);
    expect(event.touchesAny(ChangeResource.orders, ['x', 'order-1']), isTrue);
    expect(event.touchesAny(ChangeResource.shipments, ['ship-1']), isFalse);
  });

  test('payload lạ thì bỏ qua, không ném lỗi', () {
    expect(ChangeEvent.tryParse(null), isNull);
    expect(ChangeEvent.tryParse('chuỗi'), isNull);
    expect(ChangeEvent.tryParse({'eventId': 'e', 'action': 'A'}), isNull);
    final partial = ChangeEvent.tryParse({
      'eventId': 'e2',
      'action': 'SHIPMENT_DELIVERED',
      'changes': [
        {'resource': 'shipments', 'ids': ['s1', 7]},
        'rác',
      ],
    })!;
    expect(partial.changes['shipments'], ['s1']);
    expect(partial.summary, '');
  });
}
