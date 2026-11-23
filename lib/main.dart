import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/activity_counts.dart';
import 'core/network/api_client.dart';
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
  // Phiên kết thúc vì bất cứ lý do gì (đăng xuất, hết hạn, đổi mật khẩu): badge của người cũ không được ở lại.
  auth.addListener(() {
    switch (auth.status) {
      case AuthStatus.signedIn:
        realtime.start();
      case AuthStatus.signedOut:
        // Socket ở trong phòng của shop theo token lúc nối: không ngắt thì người đăng nhập sau vẫn nhận sự kiện của người trước.
        realtime.stop();
        counts.reset();
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
    ),
  );
  // Không chờ ở đây: màn chờ hiện ngay, router đổi màn khi biết đã đăng nhập hay chưa.
  auth.restore();
}
