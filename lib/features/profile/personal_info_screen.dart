import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';

/// Thông tin cá nhân, chỉ xem. BE chỉ cho nhân viên tự sửa ảnh đại diện (`AuthService.updateMe`);
/// họ tên, số điện thoại, chi nhánh do cửa hàng sửa.
class PersonalInfoScreen extends StatelessWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    final theme = context.theme;
    return FScaffold(
      header: SafeArea(
        bottom: false,
        child: FHeader.nested(
          title: const Text('Thông tin cá nhân'),
          prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        ),
      ),
      child: ListenableBuilder(
        listenable: auth,
        builder: (context, _) {
          final user = auth.user;
          String value(String? v) =>
              (v == null || v.trim().isEmpty) ? 'Chưa có' : v;
          return RefreshIndicator(
            onRefresh: auth.refreshUser,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                FTileGroup(
                  children: [
                    FTile(
                      title: const Text('Họ tên'),
                      details: Text(value(user?.fullName)),
                    ),
                    FTile(
                      title: const Text('Số điện thoại'),
                      details: Text(value(user?.phoneNumber)),
                    ),
                    FTile(
                      title: const Text('Email'),
                      details: Text(value(user?.email)),
                    ),
                    FTile(
                      title: const Text('Vai trò'),
                      details: Text(value(user?.roleName)),
                    ),
                    FTile(
                      title: const Text('Nơi làm việc'),
                      details: Text(value(user?.locationName)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Cần sửa thông tin thì báo quản lý cửa hàng.',
                  style: theme.typography.body.sm.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
