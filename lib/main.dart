import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/activity_counts.dart';
import 'core/network/api_client.dart';
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
  api.onSessionExpired = auth.sessionExpired;
  // Phiên kết thúc vì bất cứ lý do gì (đăng xuất, hết hạn, đổi mật khẩu): badge của người cũ không được ở lại.
  auth.addListener(() {
    if (auth.status == AuthStatus.signedOut) counts.reset();
  });

  runApp(IkiotApp(api: api, auth: auth, settings: settings, counts: counts));
  // Không chờ ở đây: màn chờ hiện ngay, router đổi màn khi biết đã đăng nhập hay chưa.
  auth.restore();
}
