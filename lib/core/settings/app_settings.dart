import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Ứng dụng mở chỉ đường. Apple Maps chỉ có trên iOS.
enum MapsApp { google, apple }

/// Cài đặt riêng của máy này (không đồng bộ lên BE): giao diện sáng/tối và app bản đồ.
/// Đọc lỗi thì dùng mặc định: mất cài đặt không được làm app không mở được.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs, this._themeMode, this._mapsApp);

  static const _themeKey = 'theme_mode';
  static const _mapsKey = 'maps_app';

  final SharedPreferences? _prefs;
  ThemeMode _themeMode;
  MapsApp _mapsApp;

  static Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme =
          ThemeMode.values.asNameMap()[prefs.getString(_themeKey)] ??
          ThemeMode.system;
      final maps =
          MapsApp.values.asNameMap()[prefs.getString(_mapsKey)] ??
          MapsApp.google;
      return AppSettings._(prefs, theme, maps);
    } catch (_) {
      return AppSettings._(null, ThemeMode.system, MapsApp.google);
    }
  }

  /// Bản không lưu, cho test.
  @visibleForTesting
  factory AppSettings.inMemory() =>
      AppSettings._(null, ThemeMode.system, MapsApp.google);

  ThemeMode get themeMode => _themeMode;
  MapsApp get mapsApp => _mapsApp;

  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    _prefs?.setString(_themeKey, value.name);
    notifyListeners();
  }

  set mapsApp(MapsApp value) {
    if (value == _mapsApp) return;
    _mapsApp = value;
    _prefs?.setString(_mapsKey, value.name);
    notifyListeners();
  }
}

String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'Theo hệ thống',
  ThemeMode.light => 'Sáng',
  ThemeMode.dark => 'Tối',
};

String mapsAppLabel(MapsApp app) => switch (app) {
  MapsApp.google => 'Google Maps',
  MapsApp.apple => 'Apple Maps',
};
