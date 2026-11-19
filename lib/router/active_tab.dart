import 'package:flutter/widgets.dart';

/// Tab đang mở của khung. [StatefulShellRoute] giữ nguyên trạng thái từng tab (để không mất vị trí cuộn),
/// nên một tab đã tải sẽ không tự tải lại khi quay về - mà dữ liệu của nó có thể vừa đổi ở tab khác
/// (giao xong một đơn ở Cần giao thì Lịch sử phải thấy). Màn nào cần thì nghe [ActiveTab] qua [ActiveTabReload].
class ActiveTab extends InheritedNotifier<ValueNotifier<int>> {
  const ActiveTab({
    super.key,
    required ValueNotifier<int> index,
    required super.child,
  }) : super(notifier: index);

  static ValueNotifier<int>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ActiveTab>()?.notifier;
}

/// Gọi [onActivated] mỗi lần tab [tabIndex] được chọn lại (không gọi lần mở đầu tiên: màn tự tải lúc đó).
mixin ActiveTabReload<T extends StatefulWidget> on State<T> {
  int get tabIndex;
  void onActivated();

  ValueNotifier<int>? _active;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = ActiveTab.maybeOf(context);
    if (active == _active) return;
    _active?.removeListener(_changed);
    _active = active?..addListener(_changed);
  }

  void _changed() {
    if (_active?.value == tabIndex && mounted) onActivated();
  }

  @override
  void dispose() {
    _active?.removeListener(_changed);
    super.dispose();
  }
}
