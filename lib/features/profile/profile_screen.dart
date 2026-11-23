import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_scope.dart';
import '../../core/settings/app_settings.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/option_sheet.dart';
import '../../core/widgets/tab_page.dart';
import '../../router/routes.dart';
import 'avatar_editor.dart';

/// Wireframe màn 9.
///
/// Khác wireframe: chưa có dòng "Thông báo đẩy". Push cần cấu hình Firebase cho app (google-services.json,
/// GoogleService-Info.plist) mà dự án chưa có; thêm dòng này cùng lúc nối FCM.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.auth, scope.settings]),
      builder: (context, _) {
        final theme = context.theme;
        final user = scope.auth.user;
        final settings = scope.settings;
        final subtitle = [?user?.roleName, ?user?.locationName].join(' · ');
        return TabPage(
          title: 'Tôi',
          child: RefreshIndicator(
            onRefresh: scope.auth.refreshUser,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Row(
                  children: [
                    AvatarEditor(user: user),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? '…',
                            style: theme.typography.body.lg.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: theme.typography.body.sm.copyWith(
                                color: theme.colors.mutedForeground,
                              ),
                            ),
                          if (user != null)
                            Text(
                              user.phoneNumber,
                              style: theme.typography.body.sm.copyWith(
                                color: theme.colors.mutedForeground,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FTileGroup(
                  label: const Text('Tài khoản'),
                  children: [
                    FTile(
                      prefix: const Icon(FLucideIcons.userRound),
                      title: const Text('Thông tin cá nhân'),
                      suffix: const Icon(FLucideIcons.chevronRight),
                      onPress: () => context.push(Routes.personalInfo),
                    ),
                    FTile(
                      prefix: const Icon(FLucideIcons.keyRound),
                      title: const Text('Đổi mật khẩu'),
                      suffix: const Icon(FLucideIcons.chevronRight),
                      onPress: () => context.push(Routes.changePassword),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FTileGroup(
                  label: const Text('Ứng dụng'),
                  children: [
                    FTile(
                      prefix: const Icon(FLucideIcons.sunMoon),
                      title: const Text('Giao diện'),
                      details: Text(themeModeLabel(settings.themeMode)),
                      onPress: () async {
                        final picked = await showOptionSheet(
                          context,
                          title: 'Giao diện',
                          selected: settings.themeMode,
                          options: [
                            for (final mode in ThemeMode.values)
                              (mode, themeModeLabel(mode)),
                          ],
                        );
                        if (picked != null) settings.themeMode = picked;
                      },
                    ),
                    FTile(
                      prefix: const Icon(FLucideIcons.info),
                      title: const Text('Phiên bản'),
                      details: Text(_version ?? '…'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FTileGroup(
                  children: [
                    FTile(
                      variant: FItemVariant.destructive,
                      prefix: const Icon(FLucideIcons.logOut),
                      title: const Text('Đăng xuất'),
                      onPress: () => _confirmLogout(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Đăng xuất?',
      message: 'Bạn sẽ không thấy đơn giao mới cho tới khi đăng nhập lại.',
      confirmLabel: 'Đăng xuất',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final scope = AppScope.of(context);
    await scope.auth.logout();
  }
}
