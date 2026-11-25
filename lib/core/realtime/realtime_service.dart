import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'change_event.dart';
import 'fallback_poller.dart';

/// Một kết nối Socket.IO tới IKiot-BE cho cả app, như `src/lib/socket.ts` của IKiot-FE.
///
/// - Server tự đưa socket vào phòng `user:<id>` và `tenant:<id>` theo JWT ở handshake; client không tự join gì.
/// - Token đọc lại **mỗi lần kết nối** (`setAuthFn`): access token xoay vòng sau mỗi lần refresh, token cũ sẽ bị từ chối.
/// - Server từ chối token (hết hạn) thì ngắt với lý do `io server disconnect`, và socket.io **không** tự nối lại
///   trong trường hợp đó. Khi ấy gọi [onAuthRejected] để làm mới token qua HTTP rồi tự nối lại, có giới hạn số lần.
/// - Sự kiện phát trong lúc mất kết nối (app chạy nền, mất sóng) bị mất hẳn, nên mỗi lần nối lại phát [resync]
///   để các màn tải lại một lần.
/// - Socket không nối được (proxy chặn websocket, server từ chối) thì [FallbackPoller] phát [resync] theo chu kỳ:
///   các màn vẫn tự cập nhật, chỉ chậm hơn.
class RealtimeService {
  RealtimeService({required this._tokens, this.onAuthRejected});

  final TokenStorage _tokens;

  /// Làm mới access token (vd. gọi một API để interceptor refresh). Lỗi thì thôi, lần mở app sau thử lại.
  final Future<void> Function()? onAuthRejected;

  io.Socket? _socket;
  bool _everConnected = false;
  int _authRetries = 0;
  static const _maxAuthRetries = 3;

  final _changes = StreamController<ChangeEvent>.broadcast();
  final _notifications = StreamController<void>.broadcast();
  final _resync = StreamController<void>.broadcast();
  late final _fallback = FallbackPoller(
    onTick: () {
      debugPrint('Realtime chưa nối được: tải lại theo chu kỳ');
      _resync.add(null);
    },
  );

  /// Chống trùng: FE cũng dùng `eventId` để không xử lý một sự kiện hai lần.
  final _seen = ListQueue<String>();

  Stream<ChangeEvent> get changes => _changes.stream;

  /// Có thông báo mới gửi riêng cho mình (sự kiện `notification` ở phòng `user:<id>`).
  Stream<void> get notifications => _notifications.stream;

  /// "Có thể đã lỡ sự kiện, tải lại đi": phát khi socket nối lại sau khi rơi, và theo chu kỳ khi socket không nối được.
  Stream<void> get resync => _resync.stream;

  /// Id socket đang nối, gửi kèm mỗi request (`X-Socket-Id`) để BE không phát lại thay đổi cho chính máy vừa làm.
  String? get socketId => (_socket?.connected ?? false) ? _socket!.id : null;

  void start() {
    if (_socket != null) return;
    _everConnected = false;
    _authRetries = 0;
    _fallback.start();
    final socket = io.io(
      Env.apiBaseUrl,
      io.OptionBuilder()
          // Chỉ websocket, KHÔNG thêm 'polling' như IKiot-FE. Trên Android / iOS, socket_io_client chỉ có websocket
          // (`io_transports.dart`: "Native only supports websocket"): khai 'polling' đứng đầu thì nó vẫn mở WebSocket
          // nhưng gửi `?transport=polling`, server Engine.IO đóng ngay không handshake, và app nối lại mãi mà không bao
          // giờ nhận được sự kiện nào (lỗi có thật 2026-11-25: mọi màn realtime chết, kho xuất hàng phải kéo tải lại).
          // Proxy chặn websocket thì không có đường lùi về polling ở thư viện này; api-dev nhận websocket bình thường.
          .setTransports(['websocket'])
          .enableReconnection()
          .enableForceNew()
          .setAuthFn((callback) {
            _tokens.readAccess().then(
              (token) => callback({'token': token ?? ''}),
            );
          })
          .build(),
    );
    socket
      ..onConnect((_) {
        _authRetries = 0;
        _fallback.connected();
        if (_everConnected) _resync.add(null);
        _everConnected = true;
      })
      ..onConnectError((error) {
        _fallback.disconnected();
        debugPrint('Realtime không nối được: $error');
      })
      ..onDisconnect((reason) {
        _fallback.disconnected();
        if (reason == 'io server disconnect') _recoverAuth();
      })
      ..on('entity:changed', _onChange)
      ..on('notification', (_) => _notifications.add(null));
    _socket = socket;
  }

  void stop() {
    _fallback.stop();
    _socket?.dispose();
    _socket = null;
    _seen.clear();
  }

  /// App xuống nền: ngừng tải lại theo chu kỳ.
  void pause() => _fallback.foreground(false);

  /// App trở lại từ nền: nếu socket đã rơi mà không tự nối (bị server ngắt) thì nối lại.
  void resume() {
    _fallback.foreground(true);
    final socket = _socket;
    if (socket != null && !socket.connected) socket.connect();
  }

  Future<void> _recoverAuth() async {
    if (_authRetries >= _maxAuthRetries) return;
    _authRetries++;
    try {
      await onAuthRejected?.call();
    } catch (_) {
      // Không làm mới được (mất mạng / phiên hết): để lần mở app sau thử lại.
    }
    _socket?.connect();
  }

  void _onChange(dynamic data) {
    final event = ChangeEvent.tryParse(data);
    if (event == null) {
      debugPrint('entity:changed có hình dạng lạ, bỏ qua: $data');
      return;
    }
    if (_seen.contains(event.eventId)) return;
    _seen.addLast(event.eventId);
    if (_seen.length > 100) _seen.removeFirst();
    _changes.add(event);
  }
}
