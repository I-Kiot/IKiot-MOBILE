import 'package:flutter/widgets.dart';

import '../features/auth/auth_controller.dart';
import 'activity_counts.dart';
import 'network/api_client.dart';
import 'settings/app_settings.dart';

/// Các đối tượng sống suốt vòng đời app, đưa xuống cây widget.
///
/// Cố ý chưa dùng thư viện quản lý trạng thái (Riverpod, Bloc): trạng thái chung chỉ có phiên đăng nhập,
/// cài đặt máy và hai con số badge. Khi nối socket và cần cache danh sách thì quyết định lại.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.auth,
    required this.settings,
    required this.counts,
    required super.child,
  });

  final ApiClient api;
  final AuthController auth;
  final AppSettings settings;
  final ActivityCounts counts;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope không có trong cây widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api ||
      auth != oldWidget.auth ||
      settings != oldWidget.settings ||
      counts != oldWidget.counts;
}
