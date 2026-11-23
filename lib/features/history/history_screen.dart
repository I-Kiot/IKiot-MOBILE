import 'dart:async';

import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/tab_page.dart';
import '../../core/realtime/change_event.dart';
import '../../core/realtime/live_refresh.dart';
import '../../router/active_tab.dart';
import '../../router/routes.dart';
import '../deliveries/shipment_summary.dart';
import '../deliveries/shipment_ui.dart';
import 'history_item.dart';
import 'history_repository.dart';
import '../../core/widgets/app_card.dart';

/// Wireframe màn 7. Mặc định "Hôm nay": cuối ngày shipper cần đối chiếu số tiền với cửa hàng.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

/// Bộ lọc trạng thái: `null` là tất cả.
const _statusFilters = <(String?, String)>[
  (null, 'Tất cả'),
  (ShipmentStatus.delivered, 'Đã giao'),
  (ShipmentStatus.failed, 'Không thành'),
];

class _HistoryScreenState extends State<HistoryScreen>
    with ActiveTabReload, LiveRefresh {
  @override
  bool isLiveRelevant(ChangeEvent event) =>
      event.touchesResource(ChangeResource.shipments);

  /// Chỉ tải khi đang mở tab này; tab khác thì [ActiveTabReload] tải lúc quay lại.
  @override
  void onLiveRefresh() {
    if (ActiveTab.maybeOf(context)?.value == tabIndex) _reload();
  }

  @override
  int get tabIndex => 1;

  @override
  void onActivated() => _reload();

  late final HistoryRepository _repository = HistoryRepository(
    AppScope.of(context).api,
  );
  final _scroll = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  HistoryRange _range = HistoryRange.today;
  String? _status;
  bool _searching = false;

  final List<HistoryItem> _items = [];
  HistorySummary _summary = const HistorySummary();
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  ApiException? _error;

  /// Mỗi lần đổi bộ lọc tăng lên; trang về muộn của bộ lọc cũ bị bỏ qua.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_page == 0 && !_loading && _error == null) _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _generation++;
    _page = 0;
    _hasMore = true;
    _loading = false;
    _items.clear();
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() => _loading = true);
    final (from, to) = _range.dates(DateTime.now());
    final search = _searchController.text.trim();
    try {
      final (page, summary) = await _repository.list(
        from: from,
        to: to,
        status: _status,
        search: search.isEmpty ? null : search,
        page: _page + 1,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _summary = summary;
        _page = page.page;
        _hasMore = page.hasMore;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _setRange(HistoryRange range) {
    if (range == _range) return;
    setState(() => _range = range);
    _reload();
  }

  void _setStatus(String? status) {
    if (status == _status) return;
    setState(() => _status = status);
    _reload();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching && _searchController.text.isNotEmpty) {
      _searchController.clear();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TabPage(
      title: 'Lịch sử',
      actions: [
        FHeaderAction(
          icon: Icon(_searching ? FLucideIcons.x : FLucideIcons.search),
          onPress: _toggleSearch,
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverList.list(children: _header(context)),
            ),
            ..._list(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _header(BuildContext context) {
    final theme = context.theme;
    return [
      if (_searching) ...[
        FTextField(
          control: FTextFieldControl.managed(
            controller: _searchController,
            onChange: (_) => _onSearchChanged(),
          ),
          hint: 'Tên khách hoặc mã đơn',
          autofocus: true,
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: 12),
      ],
      _Segmented(
        options: [for (final r in HistoryRange.values) r.label],
        selected: HistoryRange.values.indexOf(_range),
        onSelect: (i) => _setRange(HistoryRange.values[i]),
      ),
      const SizedBox(height: 12),
      _Stats(summary: _summary),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (status, label) in _statusFilters) ...[
              FButton(
                size: FButtonSizeVariant.sm,
                mainAxisSize: MainAxisSize.min,
                variant: _status == status
                    ? FButtonVariant.primary
                    : FButtonVariant.outline,
                onPress: () => _setStatus(status),
                child: Text(label),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (_summary.active > 0 && _status == null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Danh sách gồm cả ${_summary.active} lần giao chưa xong.',
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ),
    ];
  }

  List<Widget> _list(BuildContext context) {
    if (_items.isEmpty && _loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: FCircularProgress()),
        ),
      ];
    }
    if (_items.isEmpty && _error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: FLucideIcons.wifiOff,
            title: 'Chưa tải được lịch sử',
            message: _error!.userMessage,
            action: FButton(
              variant: FButtonVariant.outline,
              mainAxisSize: MainAxisSize.min,
              onPress: _reload,
              child: const Text('Thử lại'),
            ),
          ),
        ),
      ];
    }
    if (_items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: FLucideIcons.history,
            title: 'Không có lần giao nào',
            message: 'Đổi khoảng ngày hoặc bộ lọc để xem thêm.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverList.separated(
          itemCount: _items.length + (_hasMore ? 1 : 0),
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == _items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: FCircularProgress()),
              );
            }
            return _HistoryRow(
              item: _items[index],
              onPress: () =>
                  context.push(Routes.delivery(_items[index].summary.id)),
            );
          },
        ),
      ),
    ];
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: FTappable(
                onPress: () => onSelect(i),
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected
                        ? theme.colors.background
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    options[i],
                    style: theme.typography.body.sm.copyWith(
                      fontWeight: FontWeight.w500,
                      color: i == selected
                          ? theme.colors.foreground
                          : theme.colors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.summary});

  final HistorySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    Widget cell(String label, String value) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.typography.body.lg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final divider = Container(width: 1, height: 44, color: theme.colors.border);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          cell('Đã giao', '${summary.delivered}'),
          divider,
          cell('Không thành', '${summary.failed}'),
          divider,
          cell('Đã thu', formatMoney(summary.collectedTotal)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item, required this.onPress});

  final HistoryItem item;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final s = item.summary;
    final time = DateFormat('HH:mm dd/MM', 'vi').format(item.finishedAt);
    final collection = item.collection;
    final detail = switch (collection) {
      final c? =>
        'Thu ${formatMoney(c.amount)} · ${c.methodLabel}${c.pending ? ' (chờ tiền về)' : ''} · $time',
      null => '${s.orderCode} · $time',
    };
    return AppCard(
      child: FTappable(
        onPress: onPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.sm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ShipmentStatusBadge(status: s.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
