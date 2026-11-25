import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app_scope.dart';
import 'change_event.dart';

/// Cho một màn tự tải lại khi có `entity:changed` liên quan, giống `useLiveRefresh` của IKiot-FE.
///
/// - Sự kiện dồn dập (một thao tác chạm nhiều bảng, nhiều người cùng làm) gộp thành **một** lần tải
///   sau [liveDebounce].
/// - Socket nối lại sau khi đứt thì tải lại một lần, vì sự kiện phát lúc mất kết nối đã mất hẳn; socket không nối
///   được thì tải lại theo chu kỳ ([RealtimeService.resync]).
/// - [onLiveEvent] nhận từng sự kiện liên quan trước khi tải, để màn chi tiết báo cho người dùng biết ai vừa đổi gì.
mixin LiveRefresh<T extends StatefulWidget> on State<T> {
  /// Sự kiện này có đụng tới dữ liệu đang hiện không.
  bool isLiveRelevant(ChangeEvent event);

  /// Tải lại dữ liệu ở nền (không hiện vòng quay toàn màn).
  void onLiveRefresh();

  void onLiveEvent(ChangeEvent event) {}

  Duration get liveDebounce => const Duration(milliseconds: 600);

  StreamSubscription<ChangeEvent>? _changeSub;
  StreamSubscription<void>? _resyncSub;
  Timer? _liveTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_changeSub != null) return;
    final realtime = AppScope.of(context).realtime;
    _changeSub = realtime.changes.listen((event) {
      if (!mounted || !isLiveRelevant(event)) return;
      onLiveEvent(event);
      _scheduleLiveRefresh();
    });
    _resyncSub = realtime.resync.listen((_) => _scheduleLiveRefresh());
  }

  void _scheduleLiveRefresh() {
    _liveTimer?.cancel();
    _liveTimer = Timer(liveDebounce, () {
      if (mounted) onLiveRefresh();
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _changeSub?.cancel();
    _resyncSub?.cancel();
    super.dispose();
  }
}
