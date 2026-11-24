import 'package:flutter_test/flutter_test.dart';

import 'package:ikiot_mobile/core/paged.dart';
import 'package:ikiot_mobile/features/history/history_item.dart';
import 'package:ikiot_mobile/features/notifications/app_notification.dart';

void main() {
  group('HistoryRange.dates', () {
    final now = DateTime(2026, 11, 19, 23, 40);

    test('hôm nay là một ngày, tính trọn ngày', () {
      expect(HistoryRange.today.dates(now), ('2026-11-19', '2026-11-19'));
    });

    test('7 ngày gồm cả hôm nay', () {
      expect(HistoryRange.last7Days.dates(now), ('2026-11-13', '2026-11-19'));
    });

    test('tháng này bắt đầu từ ngày 1', () {
      expect(HistoryRange.thisMonth.dates(now), ('2026-11-01', '2026-11-19'));
    });

    test('7 ngày qua đầu tháng lùi sang tháng trước', () {
      expect(HistoryRange.last7Days.dates(DateTime(2026, 3, 2)), (
        '2026-02-24',
        '2026-03-02',
      ));
    });
  });

  test(
    'HistoryItem lấy mốc giao xong, rơi về updatedAt khi chưa giao được',
    () {
      Map<String, dynamic> row({String? deliveredAt}) => {
        'id': 's1',
        'status': deliveredAt == null ? 'FAILED' : 'DELIVERED',
        'deliveredAt': deliveredAt,
        'updatedAt': '2026-11-19T02:00:00.000Z',
        'order': {'code': 'DH1', 'customerName': 'A', 'amountDue': 0},
        'collection': {'method': 'SEPAY', 'amount': 500, 'status': 'PENDING'},
      };
      final delivered = HistoryItem.fromJson(
        row(deliveredAt: '2026-11-19T03:00:00.000Z'),
      );
      final failed = HistoryItem.fromJson(row());
      expect(delivered.finishedAt.toUtc(), DateTime.utc(2026, 11, 19, 3));
      expect(failed.finishedAt.toUtc(), DateTime.utc(2026, 11, 19, 2));
      expect(delivered.collection!.methodLabel, 'QR');
      expect(delivered.collection!.pending, isTrue);
    },
  );

  group('shipmentIdOf (push: chỉ có type + referenceId)', () {
    const id = '8e5f1da9-3e64-41ba-abf7-d97a94c8fc1e';
    test('push giao hàng mở lần giao trong referenceId', () {
      expect(shipmentIdOf(type: 'SHIPMENT_ASSIGNED', referenceId: id), id);
    });
    test('push loại khác, hoặc thiếu / rỗng referenceId, không mở gì', () {
      expect(shipmentIdOf(type: 'ORDER_PAID', referenceId: id), isNull);
      expect(shipmentIdOf(type: 'SHIPMENT_ASSIGNED'), isNull);
      expect(shipmentIdOf(type: 'SHIPMENT_ASSIGNED', referenceId: ''), isNull);
      expect(shipmentIdOf(), isNull);
    });
  });

  group('AppNotification.shipmentId', () {
    AppNotification make(String type, {String? link, String? referenceId}) =>
        AppNotification.fromJson({
          'id': 'n1',
          'type': type,
          'title': 't',
          'description': 'd',
          'isRead': false,
          'createdAt': '2026-11-19T02:00:00.000Z',
          'link': link,
          'referenceId': referenceId,
        });

    test('thông báo giao hàng mở lần giao trong referenceId', () {
      expect(make('SHIPMENT_ASSIGNED', referenceId: 'abc').shipmentId, 'abc');
    });

    test('đọc được id từ link /shipments/<uuid>', () {
      const id = '0f8fad5b-d9cb-469f-a165-70867728950e';
      expect(make('OTHER', link: '/shipments/$id').shipmentId, id);
    });

    test('thông báo đơn hàng không mở gì trong app', () {
      expect(
        make(
          'ORDER_PAID',
          link: '/sales/orders/x',
          referenceId: 'order-1',
        ).shipmentId,
        isNull,
      );
    });
  });

  test('Paged đọc pagination và giữ phần còn lại của body', () {
    final page = Paged.fromJson({
      'data': [
        {'v': 1},
      ],
      'pagination': {'page': 1, 'limit': 20, 'total': 21, 'totalPages': 2},
      'unreadCount': 3,
    }, (json) => json['v'] as int);
    expect(page.items, [1]);
    expect(page.hasMore, isTrue);
    expect(page.raw['unreadCount'], 3);
  });
}
