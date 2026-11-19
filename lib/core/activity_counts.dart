import 'package:flutter/foundation.dart';

import 'network/api_client.dart';

/// Hai con số hiện trên khung app: số lần giao chưa xong (badge tab Cần giao) và số thông báo chưa đọc (chấm trên chuông).
///
/// Làm mới lúc vào app, lúc app mở lại từ nền, và khi các màn tự tải được số mới.
/// Chưa có socket nên giữa hai lần đó con số có thể cũ (xem docs/van-de-socket-qr-giao-hang.md).
class ActivityCounts extends ChangeNotifier {
  ActivityCounts(this._api);

  final ApiClient _api;
  int _deliveries = 0;
  int _unread = 0;

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
