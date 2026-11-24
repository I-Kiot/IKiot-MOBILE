import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/notifications/app_notification.dart';
import '../network/api_client.dart';

/// Thông báo đẩy FCM, cho lúc app ở nền hoặc đã tắt. Khi app đang mở thì realtime (socket) đã cập nhật màn hình.
///
/// - BE gửi push trong mọi `notify()` tới mọi token đã đăng ký của người nhận (`user_fcm_tokens`), cùng project
///   Firebase với `android/app/google-services.json`. Payload: `notification { title, body }` +
///   `data { type, referenceId }`.
/// - Token đăng ký với BE lúc đăng nhập và mỗi khi FCM đổi token; gỡ khi đăng xuất. Ngoài ra còn **xoá token ở máy**
///   ([FirebaseMessaging.deleteToken]): phiên hết hạn thì không gọi được BE để gỡ, nhưng token đã xoá thì FCM báo
///   "not registered" và BE tự dọn, nên máy đã đăng xuất không còn nhận push của người cũ.
/// - Dùng **FCM registration token** (`getToken`/`onTokenRefresh`/`deleteToken`), dù firebase_messaging 17 đánh dấu
///   deprecated: API mới (`register`/`onRegistered`) trả Firebase Installation ID cho kiểu gửi "direct-send", còn BE
///   gửi bằng `sendEachForMulticast({ tokens })` của firebase-admin - FID không phải token mà hàm đó nhận.
///   Chỉ chuyển khi BE chuyển cách gửi.
/// - Chưa cấu hình (iOS chưa có `GoogleService-Info.plist`, hoặc máy không có Google Play) thì mọi hàm là no-op.
class PushService {
  PushService(this._api);

  final ApiClient _api;

  bool _ready = false;
  String? _registered;
  StreamSubscription<String>? _refreshSub;

  final _opened = StreamController<String>.broadcast();
  final _received = StreamController<void>.broadcast();

  /// Người dùng bấm một push giao hàng: id lần giao cần mở.
  Stream<String> get openedShipments => _opened.stream;

  /// Push đến lúc app đang mở (hệ thống không tự hiện): để làm mới badge.
  Stream<void> get receivedInForeground => _received.stream;

  /// Push đã bấm để mở app từ trạng thái tắt hẳn; đọc một lần, sau khi đã biết đăng nhập hay chưa.
  String? _launchShipment;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (error) {
      debugPrint('Push tắt: Firebase chưa cấu hình cho nền tảng này ($error)');
      return;
    }
    _ready = true;
    FirebaseMessaging.onMessage.listen((_) => _received.add(null));
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _launchShipment = _shipmentOf(initial);
  }

  /// Lần giao của push đã mở app lúc khởi động, nếu có. Chỉ trả một lần.
  String? takeLaunchShipment() {
    final id = _launchShipment;
    _launchShipment = null;
    return id;
  }

  /// Gọi khi đã đăng nhập. Hỏi quyền (Android 13+, iOS), rồi đăng ký token với BE. Không bao giờ ném lỗi:
  /// push hỏng không được chặn shipper dùng app.
  Future<void> register() async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) await _send(token);
      // ignore: deprecated_member_use
      _refreshSub ??= messaging.onTokenRefresh.listen(
        (token) => _send(token).catchError((_) {}),
      );
    } catch (error) {
      debugPrint('Không đăng ký được push: $error');
    }
  }

  /// Gọi **trước** khi xoá token phiên, vì `DELETE /notifications/device-token` cần access token.
  Future<void> unregister() async {
    if (!_ready) return;
    await _refreshSub?.cancel();
    _refreshSub = null;
    final token = _registered;
    _registered = null;
    try {
      if (token != null) {
        await _api.delete(
          '/notifications/device-token',
          body: {'token': token},
        );
      }
    } catch (_) {
      // Phiên đã hết hoặc mất mạng: deleteToken bên dưới vẫn chặn được push.
    }
    try {
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _send(String token) async {
    await _api.post(
      '/notifications/device-token',
      body: {
        'token': token,
        'userAgent': 'IKiot Giao Hàng (${defaultTargetPlatform.name})',
      },
    );
    _registered = token;
  }

  void _onOpened(RemoteMessage message) {
    final id = _shipmentOf(message);
    if (id != null) _opened.add(id);
  }

  String? _shipmentOf(RemoteMessage message) => shipmentIdOf(
    type: message.data['type'] as String?,
    referenceId: message.data['referenceId'] as String?,
  );
}
