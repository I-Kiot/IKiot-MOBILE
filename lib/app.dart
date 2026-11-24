import 'dart:async';

import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/activity_counts.dart';
import 'core/app_scope.dart';
import 'core/network/api_client.dart';
import 'core/push/push_service.dart';
import 'core/realtime/realtime_service.dart';
import 'core/settings/app_settings.dart';
import 'features/auth/auth_controller.dart';
import 'router/app_router.dart';
import 'router/routes.dart';

class IkiotApp extends StatefulWidget {
  const IkiotApp({
    super.key,
    required this.api,
    required this.auth,
    required this.settings,
    required this.counts,
    required this.realtime,
    required this.push,
  });

  final ApiClient api;
  final AuthController auth;
  final AppSettings settings;
  final ActivityCounts counts;
  final RealtimeService realtime;
  final PushService push;

  @override
  State<IkiotApp> createState() => _IkiotAppState();
}

class _IkiotAppState extends State<IkiotApp> {
  late final GoRouter _router = buildRouter(widget.auth);
  StreamSubscription<String>? _pushTaps;

  /// Lần giao từ push đã bấm nhưng chưa mở được (chưa biết đăng nhập, hoặc đang ở màn đăng nhập).
  String? _pendingShipment;

  @override
  void initState() {
    super.initState();
    _pendingShipment = widget.push.takeLaunchShipment();
    _pushTaps = widget.push.openedShipments.listen((id) {
      _pendingShipment = id;
      _openPending();
    });
    widget.auth.addListener(_openPending);
    _openPending();
  }

  /// Mở lần giao của push sau khi router đã đưa người dùng vào trong (redirect của splash/đăng nhập chạy trước).
  void _openPending() {
    final id = _pendingShipment;
    if (id == null || widget.auth.status != AuthStatus.signedIn) return;
    _pendingShipment = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final location = _router.routeInformationProvider.value.uri.path;
      // Từ splash/đăng nhập thì `go` (thay cả ngăn xếp, quay lại là về Cần giao); đang dùng app thì `push`
      // để quay lại đúng màn đang xem.
      if (location == Routes.splash || location == Routes.login) {
        _router.go(Routes.delivery(id));
      } else {
        _router.push(Routes.delivery(id));
      }
    });
  }

  @override
  void dispose() {
    widget.auth.removeListener(_openPending);
    _pushTaps?.cancel();
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
            title: 'IKiot Giao Hàng',
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
