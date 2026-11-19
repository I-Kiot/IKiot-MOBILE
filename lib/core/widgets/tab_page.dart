import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// Một trang gốc của tab: header tiêu đề trái (FHeader gốc) và phần thân.
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
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
            child: FHeader(title: Text(title), suffixes: actions),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
