import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/activity_counts.dart';
import 'core/network/api_client.dart';
import 'core/push/push_service.dart';
import 'core/realtime/realtime_service.dart';
import 'core/settings/app_settings.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');
  final settings = await AppSettings.load();

  final tokens = TokenStorage();
  final api = ApiClient(tokens: tokens);
  final auth = AuthController(AuthRepository(api: api, tokens: tokens));
  final counts = ActivityCounts(api);
  final realtime = RealtimeService(
    tokens: tokens,
    // Server từ chối token cũ: một lời gọi HTTP bất kỳ để interceptor làm mới token, rồi socket tự nối lại.
    onAuthRejected: () => api.get('/auth/me'),
  );
  api.socketIdProvider = () => realtime.socketId;
  counts.listenTo(realtime);
  api.onSessionExpired = auth.sessionExpired;
  final push = PushService(api);
  await push.init();
  auth.beforeSignOut = push.unregister;
  // Push đến lúc app đang mở: hệ thống không hiện, realtime đã lo màn hình; chỉ làm mới badge cho chắc.
  push.receivedInForeground.listen((_) => counts.refresh());
  // Phiên kết thúc vì bất cứ lý do gì (đăng xuất, hết hạn, đổi mật khẩu): badge của người cũ không được ở lại.
  auth.addListener(() {
    switch (auth.status) {
      case AuthStatus.signedIn:
        realtime.start();
        push.register();
      case AuthStatus.signedOut:
        // Socket ở trong phòng của shop theo token lúc nối: không ngắt thì người đăng nhập sau vẫn nhận sự kiện của người trước.
        realtime.stop();
        counts.reset();
        // Đăng xuất chủ động đã gỡ ở beforeSignOut; còn phiên hết hạn thì tới đây mới biết: xoá token ở máy.
        push.unregister();
      case AuthStatus.unknown:
        break;
    }
  });

  runApp(
    IkiotApp(
      api: api,
      auth: auth,
      settings: settings,
      counts: counts,
      realtime: realtime,
      push: push,
    ),
  );
  // Không chờ ở đây: màn chờ hiện ngay, router đổi màn khi biết đã đăng nhập hay chưa.
  auth.restore();
}
