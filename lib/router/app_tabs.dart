import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// Tên và icon của ba tab, dùng chung cho thanh tab dưới ([HomeShell]) và tiêu đề trang ([TabPage]),
/// để hai chỗ không bao giờ lệch nhau. Thứ tự là thứ tự các nhánh trong `StatefulShellRoute`.
enum AppTab {
  deliveries('Cần giao', FLucideIcons.truck),
  history('Lịch sử', FLucideIcons.history),
  profile('Tôi', FLucideIcons.circleUserRound);

  const AppTab(this.label, this.icon);

  final String label;
  final IconData icon;
}
