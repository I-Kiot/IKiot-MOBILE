import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/activity_counts.dart';
import 'core/app_scope.dart';
import 'core/network/api_client.dart';
import 'core/realtime/realtime_service.dart';
import 'core/settings/app_settings.dart';
import 'features/auth/auth_controller.dart';
import 'router/app_router.dart';

class IkiotApp extends StatefulWidget {
  const IkiotApp({
    super.key,
    required this.api,
    required this.auth,
    required this.settings,
    required this.counts,
    required this.realtime,
  });

  final ApiClient api;
  final AuthController auth;
  final AppSettings settings;
  final ActivityCounts counts;
  final RealtimeService realtime;

  @override
  State<IkiotApp> createState() => _IkiotAppState();
}

class _IkiotAppState extends State<IkiotApp> {
  late final GoRouter _router = buildRouter(widget.auth);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      api: widget.api,
      auth: widget.auth,
      settings: widget.settings,
      counts: widget.counts,
      realtime: widget.realtime,
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) {
          // Theme neutral của forui = shadcn neutral mà IKiot-FE dùng.
          final dark = switch (widget.settings.themeMode) {
            ThemeMode.dark => true,
            ThemeMode.light => false,
            ThemeMode.system =>
              MediaQuery.platformBrightnessOf(context) == Brightness.dark,
          };
          final theme =
              (dark ? FTheme.neutral.dark : FTheme.neutral.light).touch;
          return MaterialApp.router(
            title: 'iKiot Giao hàng',
            debugShowCheckedModeBanner: false,
            routerConfig: _router,
            locale: const Locale('vi'),
            supportedLocales: const [Locale('vi')],
            // Đã gồm delegate của Material, Cupertino và Widgets.
            localizationsDelegates: FLocalizations.localizationsDelegates,
            theme: theme.toApproximateMaterialTheme(),
            builder: (context, child) => FTheme(
              data: theme,
              child: FToaster(child: child!),
            ),
          );
        },
      ),
    );
  }
}
