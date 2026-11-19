import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// FCard có lề trong. Ở forui 0.28 builder mặc định của FCard trả thẳng `child`, không áp `style.padding`
/// (bố cục thẻ được coi là "snippet" tự sinh), nên dùng FCard trơn thì chữ dính sát viền.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FCard(
    builder: (context, style, child) =>
        Padding(padding: style.padding, child: child),
    child: child,
  );
}
