import 'dart:async';

/// Đường lui khi không có realtime: socket không nối được thì cứ [interval] gọi [onTick] một lần để các màn tự gọi
/// lại API, thay vì đứng yên tới khi shipper kéo tải lại.
///
/// Không lùi về transport polling của Socket.IO được: trong socket_io_client, polling chỉ có trên web
/// (`polling_transport.dart` dùng `XMLHttpRequest`), Android / iOS chỉ có websocket. Nên đường lui nằm ở tầng app:
/// hỏi lại REST API theo chu kỳ.
///
/// - Chạy khi: đã [start], socket đang rơi, app đang mở. Socket nối lại thì dừng (màn đã tải lại một lần nhờ sự kiện
///   nối lại của [RealtimeService]).
/// - App xuống nền thì dừng hẳn, để không tốn pin và mạng cho màn hình không ai nhìn.
/// - Quay lại app mà socket vẫn rơi thì gọi một nhịp ngay, vì dữ liệu có thể đã cũ cả quãng chạy nền.
class FallbackPoller {
  FallbackPoller({
    required this.onTick,
    this.interval = const Duration(seconds: 20),
  });

  final void Function() onTick;
  final Duration interval;

  bool _started = false;
  bool _connected = false;
  bool _foreground = true;
  Timer? _timer;

  /// Đang gọi API theo chu kỳ (để log / hiển thị nếu cần).
  bool get isPolling => _timer != null;

  void start() {
    _started = true;
    _connected = false;
    _sync();
  }

  void stop() {
    _started = false;
    _sync();
  }

  void connected() {
    _connected = true;
    _sync();
  }

  void disconnected() {
    _connected = false;
    _sync();
  }

  void foreground(bool value) {
    if (value == _foreground) return;
    _foreground = value;
    final wasPolling = isPolling;
    _sync();
    if (value && !wasPolling && isPolling) onTick();
  }

  void _sync() {
    final shouldPoll = _started && !_connected && _foreground;
    if (shouldPoll && _timer == null) {
      _timer = Timer.periodic(interval, (_) => onTick());
    } else if (!shouldPoll) {
      _timer?.cancel();
      _timer = null;
    }
  }
}
