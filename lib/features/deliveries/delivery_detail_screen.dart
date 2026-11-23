import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/toast.dart';
import '../../router/routes.dart';
import '../../core/realtime/change_event.dart';
import '../../core/realtime/live_refresh.dart';
import 'deliver_sheet.dart';
import 'deliveries_repository.dart';
import 'fail_sheet.dart';
import 'proof_photos.dart';
import 'shipment_detail.dart';
import 'shipment_summary.dart';
import 'shipment_ui.dart';
import '../../core/widgets/app_card.dart';

/// Wireframe màn 3. Nút ở đáy đổi theo trạng thái:
///
/// | Trạng thái | Nút |
/// | --- | --- |
/// | CREATED | Đã lấy hàng |
/// | PICKED_UP | không có: chờ kho xác nhận xuất hàng (`POST /orders/:id/ship`, việc của kho) |
/// | IN_TRANSIT, OUT_FOR_DELIVERY | Không thành · Đã giao |
/// | FAILED | Đã giao (giao lại) |
/// | DELIVERED, QR chưa về đủ tiền | Mở mã QR |
///
/// Khác wireframe ở bước PICKED_UP: BE chỉ cho giao khi đơn đã SHIPPING, và bước đó do kho bấm.
/// "Đang đi giao" (OUT_FOR_DELIVERY) là nhật trình không bắt buộc, nên là một dòng trong thân màn chứ không phải nút chính.
class DeliveryDetailScreen extends StatefulWidget {
  const DeliveryDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen>
    with LiveRefresh {
  @override
  bool isLiveRelevant(ChangeEvent event) =>
      event.touchesId(ChangeResource.shipments, widget.id) ||
      event.touchesId(ChangeResource.orders, _shipment?.summary.orderId);

  /// Người khác vừa đổi đúng lần giao đang mở (kho xuất hàng, cửa hàng đổi shipper, tiền QR về): báo để shipper
  /// biết vì sao màn vừa đổi. Thao tác của chính máy này không tới đây (BE loại socket gửi `X-Socket-Id`).
  @override
  void onLiveEvent(ChangeEvent event) {
    if (!event.quiet && event.summary.isNotEmpty) {
      showInfoToast(context, event.summary);
    }
  }

  @override
  void onLiveRefresh() => _load();

  late final DeliveriesRepository _repository = DeliveriesRepository(
    AppScope.of(context).api,
  );
  ShipmentDetail? _shipment;
  ApiException? _error;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shipment == null && _error == null) _load();
  }

  Future<void> _load() async {
    try {
      final detail = await _repository.detail(widget.id);
      if (mounted) {
        setState(() {
          _shipment = detail;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// Chạy một thao tác ghi: thành công thì hiện ngay chi tiết BE trả về; dữ liệu cũ thì tải lại.
  Future<void> _run(
    Future<ShipmentDetail> Function() call,
    String success,
  ) async {
    setState(() => _busy = true);
    try {
      final detail = await call();
      if (!mounted) return;
      setState(() => _shipment = detail);
      showSuccessToast(context, success);
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorToast(context, error.userMessage);
      if (error.isStale) await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickUp() async {
    final ok = await confirmDialog(
      context,
      title: 'Đã lấy hàng?',
      message:
          'Xác nhận bạn đã nhận đủ hàng của đơn ${_shipment!.summary.orderCode} tại kho.',
      confirmLabel: 'Đã lấy hàng',
    );
    if (ok && mounted) {
      await _run(() => _repository.pickUp(widget.id), 'Đã lấy hàng');
    }
  }

  Future<void> _deliver() async {
    final result = await showDeliverSheet(
      context,
      shipment: _shipment!,
      repository: _repository,
    );
    await _afterSheet(result, 'Đã giao đơn ${_shipment!.summary.orderCode}');
    final delivered = result?.delivered;
    // Thu QR: mở luôn màn mã cho khách quét.
    if (mounted && delivered != null && delivered.awaitingQrMoney) {
      await _openQr();
    }
  }

  Future<void> _fail() async {
    final result = await showFailSheet(
      context,
      shipment: _shipment!,
      repository: _repository,
    );
    await _afterSheet(result, 'Đã báo giao không thành');
  }

  Future<void> _afterSheet(DeliverResult? result, String success) async {
    if (result == null || !mounted) return;
    if (result.stale) return _load();
    setState(() => _shipment = result.delivered);
    showSuccessToast(context, success);
  }

  Future<void> _openQr() async {
    await context.push(Routes.deliveryQr(widget.id));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final shipment = _shipment;
    return FScaffold(
      header: SafeArea(
        bottom: false,
        child: FHeader.nested(
          title: Text(shipment?.summary.orderCode ?? 'Lần giao'),
          prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        ),
      ),
      footer: shipment == null ? null : _footer(shipment),
      child: _body(context),
    );
  }

  Widget? _footer(ShipmentDetail s) {
    if (s.carrierType != 'INTERNAL') return null;
    final buttons = <Widget>[];
    switch (s.status) {
      case ShipmentStatus.created:
        buttons.add(
          Expanded(
            child: _primary(FLucideIcons.packageCheck, 'Đã lấy hàng', _pickUp),
          ),
        );
      case ShipmentStatus.inTransit || ShipmentStatus.outForDelivery:
        buttons
          ..add(
            FButton(
              variant: FButtonVariant.outline,
              mainAxisSize: MainAxisSize.min,
              onPress: _busy ? null : _fail,
              child: const Text('Không thành'),
            ),
          )
          ..add(const SizedBox(width: 8))
          ..add(
            Expanded(child: _primary(FLucideIcons.check, 'Đã giao', _deliver)),
          );
      case ShipmentStatus.failed:
        buttons.add(
          Expanded(
            child: _primary(FLucideIcons.check, 'Giao lại: đã giao', _deliver),
          ),
        );
      case ShipmentStatus.delivered when s.awaitingQrMoney:
        buttons.add(
          Expanded(child: _primary(FLucideIcons.qrCode, 'Mở mã QR', _openQr)),
        );
    }
    if (buttons.isEmpty) return null;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.theme.colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: buttons),
        ),
      ),
    );
  }

  Widget _primary(IconData icon, String label, VoidCallback action) => FButton(
    onPress: _busy ? null : action,
    prefix: _busy
        ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
        : Icon(icon),
    child: Text(label),
  );

  Widget _body(BuildContext context) {
    final shipment = _shipment;
    if (shipment == null && _error == null) {
      return const Center(child: FCircularProgress());
    }
    if (shipment == null) {
      return EmptyState(
        icon: FLucideIcons.wifiOff,
        title: 'Chưa tải được lần giao',
        message: _error!.userMessage,
        action: FButton(
          variant: FButtonVariant.outline,
          mainAxisSize: MainAxisSize.min,
          onPress: _load,
          child: const Text('Thử lại'),
        ),
      );
    }
    final s = shipment.summary;
    final theme = context.theme;
    final muted = theme.typography.body.sm.copyWith(
      color: theme.colors.mutedForeground,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _Track(status: s.status),
          const SizedBox(height: 16),
          if (s.status == ShipmentStatus.pickedUp) ...[
            FAlert(
              icon: const Icon(FLucideIcons.warehouse),
              title: const Text('Chờ kho xác nhận xuất hàng'),
              subtitle: const Text(
                'Kho xác nhận xong thì bạn mới giao được. Kéo xuống để tải lại.',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (shipment.carrierType != 'INTERNAL') ...[
            FAlert(
              icon: const Icon(FLucideIcons.info),
              title: const Text('Đơn giao qua đơn vị vận chuyển'),
              subtitle: const Text(
                'Hãng tự cập nhật trạng thái, không xác nhận tay được.',
              ),
            ),
            const SizedBox(height: 12),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.displayName,
                  style: theme.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (s.recipientPhone != null)
                  Text(s.recipientPhone!, style: muted),
                const SizedBox(height: 6),
                Text(
                  s.deliveryAddress ?? 'Chưa có địa chỉ',
                  style: theme.typography.body.sm,
                ),
                if (s.customerName != s.displayName) ...[
                  const SizedBox(height: 4),
                  Text('Khách của đơn: ${s.customerName}', style: muted),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (s.scheduledDate != null || s.scheduledSlot != null)
                      _Tag(icon: FLucideIcons.clock, text: _schedule(s)),
                    if (s.requiresInstallation)
                      const _Tag(
                        icon: FLucideIcons.wrench,
                        text: 'Cần lắp đặt',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FButton(
                        variant: FButtonVariant.outline,
                        onPress: s.recipientPhone == null
                            ? null
                            : () => callPhone(s.recipientPhone!),
                        prefix: const Icon(FLucideIcons.phone),
                        child: const Text('Gọi'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FButton(
                        variant: FButtonVariant.outline,
                        onPress: s.deliveryAddress == null
                            ? null
                            : () => openDirections(s.deliveryAddress!),
                        prefix: const Icon(FLucideIcons.navigation),
                        child: const Text('Chỉ đường'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Đã giao xong tiền: ẩn "Còn phải thu", hiện giờ giao và ảnh bằng chứng. Giao rồi mà tiền QR chưa về
          // thì vẫn giữ thẻ tiền, vì shipper còn phải thu tiếp.
          if (!shipment.settledDelivery)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Còn phải thu', style: muted),
                  const SizedBox(height: 2),
                  Text(
                    amountDueText(s.status, s.amountDue),
                    style: theme.typography.body.xl2.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (shipment.status == ShipmentStatus.delivered) ...[
            if (!shipment.settledDelivery) const SizedBox(height: 12),
            DeliveredCard(
              deliveredAt: shipment.deliveredAt,
              photoUrls: shipment.proofPhotoUrls,
            ),
          ],
          if (shipment.status == ShipmentStatus.inTransit &&
              shipment.carrierType == 'INTERNAL') ...[
            const SizedBox(height: 12),
            FTileGroup(
              children: [
                FTile(
                  prefix: const Icon(FLucideIcons.navigation),
                  title: const Text('Báo đang trên đường tới khách'),
                  // Một dòng ngắn: FTile cắt subtitle ở một dòng, câu dài bị "…" mất nửa ý.
                  subtitle: const Text('Không bắt buộc, cửa hàng sẽ thấy'),
                  onPress: _busy
                      ? null
                      : () => _run(
                          () => _repository.markOutForDelivery(widget.id),
                          'Đã ghi đang đi giao',
                        ),
                ),
              ],
            ),
          ],
          if (shipment.note?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ghi chú của cửa hàng',
                    style: theme.typography.body.sm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(shipment.note!, style: muted),
                ],
              ),
            ),
          ],
          if (shipment.events.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Nhật trình',
              style: theme.typography.body.sm.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final event in shipment.events.reversed)
              _EventRow(event: event),
          ],
        ],
      ),
    );
  }

  static String _schedule(ShipmentSummary s) {
    final date = s.scheduledDate == null
        ? null
        : DateFormat('dd/MM', 'vi').format(s.scheduledDate!);
    return [?date, ?s.scheduledSlot].join(' · ');
  }
}

/// Thanh 4 bước: Nhận việc → Lấy hàng → Đang giao → Đã giao.
class _Track extends StatelessWidget {
  const _Track({required this.status});

  final String status;

  int get _reached => switch (status) {
    ShipmentStatus.created => 1,
    ShipmentStatus.pickedUp => 2,
    ShipmentStatus.inTransit ||
    ShipmentStatus.outForDelivery ||
    ShipmentStatus.failed => 3,
    ShipmentStatus.delivered => 4,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    const labels = ['Nhận việc', 'Lấy hàng', 'Đang giao', 'Đã giao'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShipmentStatusBadge(status: status),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: i < _reached
                            ? theme.colors.primary
                            : theme.colors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: theme.typography.body.xs.copyWith(
                        color: i < _reached
                            ? theme.colors.foreground
                            : theme.colors.mutedForeground,
                        fontWeight: i < _reached
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colors.mutedForeground),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final ShipmentEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              DateFormat('HH:mm dd/MM', 'vi').format(event.occurredAt),
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shipmentStatusLabel(event.status),
                  style: theme.typography.body.sm,
                ),
                if (event.note?.trim().isNotEmpty ?? false)
                  Text(
                    event.note!,
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
