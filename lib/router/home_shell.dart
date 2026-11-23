import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/app_scope.dart';
import '../core/widgets/count_badge.dart';
import 'active_tab.dart';
import 'app_tabs.dart';

/// Khoá navigator gốc, để màn chi tiết đẩy lên trên thanh tab.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Khung có thanh tab dưới. Mỗi tab tự dựng header của mình, vì tiêu đề và nút góc phải khác nhau.
///
/// Làm mới badge khi vào khung (vừa đăng nhập / mở app) và mỗi lần app trở lại từ nền:
/// shipper hay khoá máy giữa hai lần giao, lúc mở lại phải thấy đơn mới được gán.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final AppLifecycleListener _lifecycle;
  late final _activeTab = ValueNotifier<int>(widget.shell.currentIndex);
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final scope = AppScope.of(context);
        scope.counts.refresh();
        scope.realtime.resume();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      AppScope.of(context).counts.refresh();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _activeTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final counts = AppScope.of(context).counts;
    return FScaffold(
      childPad: false,
      footer: ListenableBuilder(
        listenable: counts,
        builder: (context, _) => FBottomNavigationBar(
          index: shell.currentIndex,
          safeAreaBottom: true,
          // Bấm lại tab đang mở thì về đầu ngăn xếp của tab đó, như mọi app iOS/Android.
          onChange: (index) {
            shell.goBranch(index, initialLocation: index == shell.currentIndex);
            _activeTab.value = index;
          },
          children: [
            for (final tab in AppTab.values)
              FBottomNavigationBarItem(
                icon: tab == AppTab.deliveries
                    ? CountBadge(
                        count: counts.deliveries,
                        child: Icon(tab.icon),
                      )
                    : Icon(tab.icon),
                label: Text(tab.label),
              ),
          ],
        ),
      ),
      child: ActiveTab(index: _activeTab, child: shell),
    );
  }
}
