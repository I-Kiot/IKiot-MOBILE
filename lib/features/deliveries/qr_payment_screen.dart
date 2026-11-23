import 'dart:async';

import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/toast.dart';
import '../../core/realtime/change_event.dart';
import '../../core/realtime/live_refresh.dart';
import 'deliveries_repository.dart';
import 'shipment_detail.dart';
import '../../core/widgets/app_card.dart';

/// Wireframe màn 5: quay điện thoại cho khách quét.
///
/// Tiền về được phát hiện bằng cách **hỏi lại BE mỗi 5 giây** khi mã còn chờ. Socket `order:paid` của BE
/// có sẵn nhưng app chưa nối Socket.IO; khi nối thì bỏ vòng hỏi này.
class QrPaymentScreen extends StatefulWidget {
  const QrPaymentScreen({super.key, required this.id});

  final String id;

  @override
  State<QrPaymentScreen> createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends State<QrPaymentScreen> with LiveRefresh {
  /// Tiền QR về phát `ORDER_QR_PAID` / `ORDER_QR_PARTIALLY_PAID` theo id đơn (webhook SePay).
  @override
  bool isLiveRelevant(ChangeEvent event) =>
      event.touchesId(ChangeResource.shipments, widget.id) ||
      event.touchesId(ChangeResource.orders, _shipment?.summary.orderId);

  @override
  Duration get liveDebounce => const Duration(milliseconds: 150);

  @override
  void onLiveRefresh() => _load(silent: true);

  late final DeliveriesRepository _repository = DeliveriesRepository(
    AppScope.of(context).api,
  );
  ShipmentDetail? _shipment;
  ApiException? _error;
  bool _busy = false;
  Timer? _poll;
  Timer? _clock;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shipment == null && _error == null) _load();
  }

  @override
  void initState() {
    super.initState();
    // Dự phòng khi socket rơi (mất sóng, app vừa mở lại): realtime là đường chính, nên hỏi thưa.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_waiting && !_busy) _load(silent: true);
    });
    // Đồng hồ đếm ngược chạy theo giây.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _waiting) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  QrPayment? get _payment => _shipment?.payment;
  bool get _expired {
    final p = _payment;
    return p != null &&
        (p.status == QrPaymentStatus.expired ||
            p.expired ||
            p.qrUrl == null ||
            DateTime.now().isAfter(p.expiresAt));
  }

  bool get _waiting => _payment?.status == QrPaymentStatus.pending && !_expired;
  bool get _settled => _shipment != null && !_shipment!.awaitingQrMoney;

  Future<void> _load({bool silent = false}) async {
    try {
      final detail = await _repository.detail(widget.id);
      if (!mounted) return;
      final justPaid =
          _shipment != null && !_settled && !detail.awaitingQrMoney;
      setState(() {
        _shipment = detail;
        _error = null;
      });
      if (justPaid) showSuccessToast(context, 'Khách đã chuyển khoản');
    } on ApiException catch (error) {
      if (mounted && !silent) setState(() => _error = error);
    }
  }

  Future<void> _act(
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

  Future<void> _payCash() async {
    final due = _shipment!.amountDue > 0
        ? _shipment!.amountDue
        : (_payment?.amount ?? 0);
    final ok = await confirmDialog(
      context,
      title: 'Khách trả tiền mặt?',
      message:
          'Mã QR sẽ bị huỷ và ghi nhận bạn đã thu ${formatMoney(due)} tiền mặt. Bạn giữ tiền tới khi nộp lại cửa hàng.',
      confirmLabel: 'Đã thu ${formatMoney(due)}',
    );
    if (ok && mounted) {
      await _act(
        () => _repository.payCash(widget.id),
        'Đã ghi nhận thu tiền mặt',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: SafeArea(
        bottom: false,
        child: FHeader.nested(
          title: const Text('Khách quét để trả'),
          prefixes: [
            FHeaderAction(
              icon: const Icon(FLucideIcons.x),
              onPress: () => context.pop(),
            ),
          ],
        ),
      ),
      footer: _footer(),
      child: _body(context),
    );
  }

  Widget? _footer() {
    final shipment = _shipment;
    if (shipment == null) return null;
    if (_settled) {
      return _Dock(
        children: [
          Expanded(
            child: FButton(
              onPress: () => context.pop(),
              child: const Text('Xong'),
            ),
          ),
        ],
      );
    }
    return _Dock(
      children: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: _busy ? null : _payCash,
            child: const Text('Khách trả tiền mặt'),
          ),
        ),
        if (_expired || shipment.payment?.status == QrPaymentStatus.paid) ...[
          const SizedBox(width: 8),
          Expanded(
            child: FButton(
              onPress: _busy
                  ? null
                  : () => _act(
                      () => _repository.reissueQr(widget.id),
                      'Đã tạo mã QR mới',
                    ),
              prefix: const Icon(FLucideIcons.refreshCw),
              child: Text(_expired ? 'Tạo lại mã' : 'QR số còn lại'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _body(BuildContext context) {
    final theme = context.theme;
    final shipment = _shipment;
    if (shipment == null && _error == null) {
      return const Center(child: FCircularProgress());
    }
    if (shipment == null) {
      return EmptyState(
        icon: FLucideIcons.wifiOff,
        title: 'Chưa tải được',
        message: _error!.userMessage,
      );
    }
    if (_settled) {
      return const EmptyState(
        icon: FLucideIcons.circleCheck,
        title: 'Đã nhận đủ tiền',
        message: 'Đơn đã thanh toán xong.',
      );
    }
    final payment = _payment!;
    final partial =
        payment.status == QrPaymentStatus.paid && shipment.amountDue > 0;
    final remaining = payment.expiresAt.difference(DateTime.now());
    final muted = theme.typography.body.sm.copyWith(
      color: theme.colors.mutedForeground,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Text(
          partial ? 'Khách chuyển thiếu, còn phải thu' : 'Số tiền',
          textAlign: TextAlign.center,
          style: muted,
        ),
        const SizedBox(height: 4),
        Text(
          formatMoney(partial ? shipment.amountDue : payment.amount),
          textAlign: TextAlign.center,
          style: theme.typography.body.xl3.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (partial)
          Text(
            'Đã nhận ${formatMoney(payment.amount)}',
            textAlign: TextAlign.center,
            style: muted,
          ),
        const SizedBox(height: 20),
        if (_waiting)
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              // Nền trắng cả khi giao diện tối: máy quét của khách cần tương phản đen trên trắng.
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colors.border),
              ),
              child: Image.network(
                payment.qrUrl!,
                width: 240,
                height: 240,
                errorBuilder: (context, error, stack) => const SizedBox(
                  width: 240,
                  height: 240,
                  child: Center(child: Text('Không tải được ảnh mã QR')),
                ),
              ),
            ),
          )
        else if (!partial)
          AppCard(
            child: Text(
              'Mã QR đã hết hạn. Tạo mã mới cho khách quét, hoặc thu tiền mặt.',
              style: theme.typography.body.sm,
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Nội dung: ${payment.reference}',
          textAlign: TextAlign.center,
          style: muted,
        ),
        if (_waiting) ...[
          const SizedBox(height: 12),
          Center(
            child: FBadge(
              variant: FBadgeVariant.secondary,
              child: const Text('Đang chờ khách chuyển…'),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mã hết hạn sau ${_mmss(remaining)}',
            textAlign: TextAlign.center,
            style: muted,
          ),
          const SizedBox(height: 12),
          Text(
            'Tiền về là màn tự chuyển sang "Đã nhận", không cần bấm gì.',
            textAlign: TextAlign.center,
            style: muted,
          ),
        ],
      ],
    );
  }

  static String _mmss(Duration d) {
    if (d.isNegative) return '00:00';
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.theme.colors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: children),
      ),
    ),
  );
}
