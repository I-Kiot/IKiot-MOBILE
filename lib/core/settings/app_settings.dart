import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Cài đặt riêng của máy này (không đồng bộ lên BE): giao diện sáng/tối.
/// Đọc lỗi thì dùng mặc định: mất cài đặt không được làm app không mở được.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs, this._themeMode);

  static const _themeKey = 'theme_mode';

  final SharedPreferences? _prefs;
  ThemeMode _themeMode;

  static Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme =
          ThemeMode.values.asNameMap()[prefs.getString(_themeKey)] ??
          ThemeMode.system;
      return AppSettings._(prefs, theme);
    } catch (_) {
      return AppSettings._(null, ThemeMode.system);
    }
  }

  /// Bản không lưu, cho test.
  @visibleForTesting
  factory AppSettings.inMemory() => AppSettings._(null, ThemeMode.system);

  ThemeMode get themeMode => _themeMode;

  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    _prefs?.setString(_themeKey, value.name);
    notifyListeners();
  }
}

String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'Theo hệ thống',
  ThemeMode.light => 'Sáng',
  ThemeMode.dark => 'Tối',
};
