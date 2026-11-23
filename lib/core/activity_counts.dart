import 'package:flutter/foundation.dart';

import 'dart:async';

import 'network/api_client.dart';
import 'realtime/change_event.dart';
import 'realtime/realtime_service.dart';

/// Hai con số hiện trên khung app: số lần giao chưa xong (badge tab Cần giao) và số thông báo chưa đọc (chấm trên chuông).
///
/// Làm mới lúc vào app, lúc app mở lại từ nền, khi các màn tự tải được số mới, và theo realtime:
/// một lần giao đổi (`entity:changed` chạm `shipments`) hoặc có thông báo mới gửi cho mình.
class ActivityCounts extends ChangeNotifier {
  ActivityCounts(this._api);

  final ApiClient _api;
  int _deliveries = 0;
  int _unread = 0;

  Timer? _debounce;

  /// Nghe realtime. Gộp các sự kiện dồn dập thành một lần gọi lại.
  void listenTo(RealtimeService realtime) {
    realtime.changes
        .where((e) => e.touchesResource(ChangeResource.shipments))
        .listen((_) => _scheduleRefresh());
    realtime.notifications.listen((_) => _scheduleRefresh());
    realtime.reconnected.listen((_) => _scheduleRefresh());
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), refresh);
  }

  int get deliveries => _deliveries;
  int get unread => _unread;

  set deliveries(int value) {
    if (value == _deliveries) return;
    _deliveries = value;
    notifyListeners();
  }

  set unread(int value) {
    if (value == _unread) return;
    _unread = value;
    notifyListeners();
  }

  /// Lỗi mạng thì giữ số cũ: badge sai một lúc còn hơn badge nhấp nháy về 0.
  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        _api.get('/shipments/mine'),
        _api.get('/notifications/unread-count'),
      ]);
      _deliveries = (results[0] as List<dynamic>).length;
      _unread =
          ((results[1] as Map<String, dynamic>)['count'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (_) {
      // Bỏ qua có chủ đích, xem chú thích trên.
    }
  }

  void reset() {
    _deliveries = 0;
    _unread = 0;
    notifyListeners();
  }
}
