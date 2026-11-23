import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/count_badge.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/tab_page.dart';
import '../../core/realtime/change_event.dart';
import '../../core/realtime/live_refresh.dart';
import '../../router/active_tab.dart';
import '../../router/routes.dart';
import 'deliveries_repository.dart';
import 'shipment_summary.dart';
import 'shipment_ui.dart';
import '../../core/widgets/app_card.dart';
import '../../router/app_tabs.dart';

/// Wireframe màn 2 (và màn 8 khi rỗng). Bản khung: tải, nhóm, kéo để làm mới.
/// Chưa có: badge trên tab, tự làm mới qua socket / push, chuông thông báo.
class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen>
    with ActiveTabReload, LiveRefresh {
  /// Mọi thay đổi lần giao (có thể là đơn mới được gán cho mình), hoặc thay đổi một đơn đang nằm trong danh sách
  /// (kho vừa xuất hàng, đơn bị huỷ). Không tải lại theo mọi đơn của shop: bán hàng tại quầy cũng phát sự kiện.
  @override
  bool isLiveRelevant(ChangeEvent event) =>
      event.touchesResource(ChangeResource.shipments) ||
      event.touchesAny(
        ChangeResource.orders,
        (_items ?? const []).map((s) => s.orderId),
      );

  @override
  void onLiveRefresh() => _load();

  @override
  int get tabIndex => 0;

  @override
  void onActivated() => _load();

  late final DeliveriesRepository _repository = DeliveriesRepository(
    AppScope.of(context).api,
  );
  List<ShipmentSummary>? _items;
  ApiException? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_items == null && _error == null) _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repository.mine();
      if (mounted) AppScope.of(context).counts.deliveries = items.length;
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = AppScope.of(context).counts;
    return TabPage(
      tab: AppTab.deliveries,
      actions: [
        ListenableBuilder(
          listenable: counts,
          builder: (context, _) => FHeaderAction(
            icon: CountBadge(
              count: counts.unread,
              child: const Icon(FLucideIcons.bell),
            ),
            onPress: () async {
              await context.push(Routes.notifications);
              // Một thông báo vừa đọc có thể là đơn mới được gán.
              if (mounted) await _load();
            },
          ),
        ),
      ],
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final items = _items;
    if (items == null && _error == null) {
      return const Center(child: FCircularProgress());
    }
    if (items == null) {
      return EmptyState(
        icon: FLucideIcons.wifiOff,
        title: 'Chưa tải được đơn',
        message: _error!.userMessage,
        action: FButton(
          variant: FButtonVariant.outline,
          onPress: _load,
          mainAxisSize: MainAxisSize.min,
          child: const Text('Thử lại'),
        ),
      );
    }

    // Nhóm theo việc phải làm tiếp: giao được ngay, chờ kho xuất, rồi chờ đi lấy hàng.
    final onTheWay = items
        .where((s) => !s.awaitingPickUp && s.status != ShipmentStatus.pickedUp)
        .toList();
    final waitingWarehouse = items
        .where((s) => s.status == ShipmentStatus.pickedUp)
        .toList();
    final toPickUp = items.where((s) => s.awaitingPickUp).toList();
    final totalDue = items.fold<num>(0, (sum, s) => sum + s.amountDue);

    return RefreshIndicator(
      onRefresh: _load,
      child: items.isEmpty
          // ListView để kéo làm mới được cả khi rỗng.
          ? ListView(
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: FLucideIcons.truck,
                  title: 'Chưa có đơn nào cần giao',
                  message: 'Khi cửa hàng giao đơn cho bạn, bạn sẽ nhận thông báo và đơn hiện ở đây.',
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _DueCard(total: totalDue, count: items.length),
                if (onTheWay.isNotEmpty)
                  ..._group(context, 'Đang đi giao', onTheWay),
                if (waitingWarehouse.isNotEmpty)
                  ..._group(context, 'Chờ kho xuất hàng', waitingWarehouse),
                if (toPickUp.isNotEmpty)
                  ..._group(context, 'Chờ lấy hàng', toPickUp),
              ],
            ),
    );
  }

  List<Widget> _group(
    BuildContext context,
    String label,
    List<ShipmentSummary> items,
  ) {
    final theme = context.theme;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.typography.body.sm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${items.length}',
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
      FTileGroup(
        children: [
          for (final item in items)
            FTile(
              title: Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  item.deliveryAddress ?? 'Chưa có địa chỉ',
                  item.orderCode,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              details: Text(amountDueText(item.status, item.amountDue)),
              onPress: () async {
                // Tải lại khi quay về: màn chi tiết có thể vừa đổi trạng thái hoặc kết thúc lần giao.
                await context.push(Routes.delivery(item.id));
                if (mounted) await _load();
              },
            ),
        ],
      ),
    ];
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard({required this.total, required this.count});

  final num total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Còn phải thu, $count đơn',
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMoney(total),
                  style: theme.typography.body.xl2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(FLucideIcons.wallet, color: theme.colors.mutedForeground),
        ],
      ),
    );
  }
}
