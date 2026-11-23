import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../router/app_tabs.dart';

/// Một trang gốc của tab: header (icon + tiêu đề của tab, canh trái) và phần thân.
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.tab,
    required this.child,
    this.actions = const [],
  });

  final AppTab tab;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // FHeader tự có lề ngang; thêm 4 để tiêu đề thẳng hàng với nội dung lề 16 bên dưới.
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FHeader(
              title: Row(
                children: [
                  // Cùng icon với tab ở thanh dưới, nhỏ hơn chữ một chút để chữ vẫn là thứ đọc trước.
                  Icon(tab.icon, size: 26),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(tab.label, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              suffixes: actions,
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
