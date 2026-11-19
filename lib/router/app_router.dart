import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/deliveries/deliveries_screen.dart';
import '../features/deliveries/delivery_detail_screen.dart';
import '../features/deliveries/qr_payment_screen.dart';
import '../features/history/history_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/change_password_screen.dart';
import '../features/profile/personal_info_screen.dart';
import '../features/profile/profile_screen.dart';
import 'home_shell.dart';
import 'routes.dart';

/// Ba tab trong một [StatefulShellRoute]: mỗi tab giữ ngăn xếp màn và vị trí cuộn riêng,
/// nên chuyển qua Lịch sử rồi quay lại Cần giao không mất chỗ đang xem.
GoRouter buildRouter(AuthController auth) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;
      return switch (auth.status) {
        AuthStatus.unknown => location == Routes.splash ? null : Routes.splash,
        AuthStatus.signedOut => location == Routes.login ? null : Routes.login,
        AuthStatus.signedIn =>
          (location == Routes.login || location == Routes.splash)
              ? Routes.deliveries
              : null,
      };
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.deliveries,
                builder: (context, state) => const DeliveriesScreen(),
                routes: [
                  // Chi tiết nằm ngoài shell: màn đẩy sang che thanh tab, như wireframe màn 3.
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        DeliveryDetailScreen(id: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'qr',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) =>
                            QrPaymentScreen(id: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.history,
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'info',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const PersonalInfoScreen(),
                  ),
                  GoRoute(
                    path: 'password',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ChangePasswordScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    navigatorKey: rootNavigatorKey,
  );
}
