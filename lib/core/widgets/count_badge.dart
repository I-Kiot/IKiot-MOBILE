import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// Số đỏ ở góc trên phải một icon (tab, chuông). forui chưa có badge cho mục điều hướng nên tự dựng.
/// `count` 0 thì chỉ vẽ icon.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    final theme = context.theme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -6,
          right: -10,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18),
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colors.destructive,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: theme.colors.background, width: 2),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.destructiveForeground,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
