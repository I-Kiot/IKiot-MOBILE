import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/toast.dart';
import 'deliver_sheet.dart';
import 'deliveries_repository.dart';
import 'shipment_detail.dart';

/// Lý do hay gặp, bấm một lần thay vì gõ bằng một tay. Ghép vào đầu ghi chú gửi lên (BE chỉ có một ô `note`).
const failReasons = [
  'Khách không nghe máy',
  'Khách hẹn ngày khác',
  'Sai địa chỉ',
  'Khách từ chối nhận',
  'Hàng hư hỏng',
];

/// Ghép lý do và ghi chú thành `note` gửi BE. Rỗng khi chưa có gì.
String composeFailNote(String? reason, String extra) {
  final trimmed = extra.trim();
  if (reason == null) return trimmed;
  return trimmed.isEmpty ? reason : '$reason: $trimmed';
}

/// Wireframe màn 6. Trả [DeliverResult]: chi tiết mới, hoặc `stale` khi phải tải lại.
Future<DeliverResult?> showFailSheet(
  BuildContext context, {
  required ShipmentDetail shipment,
  required DeliveriesRepository repository,
}) => showFSheet<DeliverResult>(
  context: context,
  side: FLayout.btt,
  useRootNavigator: true,
  mainAxisMaxRatio: 0.92,
  builder: (context) => _FailSheet(shipment: shipment, repository: repository),
);

class _FailSheet extends StatefulWidget {
  const _FailSheet({required this.shipment, required this.repository});

  final ShipmentDetail shipment;
  final DeliveriesRepository repository;

  @override
  State<_FailSheet> createState() => _FailSheetState();
}

class _FailSheetState extends State<_FailSheet> {
  final _extra = TextEditingController();
  String? _reason;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _extra.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _extra.dispose();
    super.dispose();
  }

  String get _note => composeFailNote(_reason, _extra.text);

  Future<void> _submit() async {
    if (_note.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final failed = await widget.repository.fail(widget.shipment.id, _note);
      if (mounted) {
        Navigator.of(context)
            .pop<DeliverResult>((delivered: failed, stale: false));
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorToast(context, error.userMessage);
      if (error.isStale) {
        Navigator.of(context)
            .pop<DeliverResult>((delivered: null, stale: true));
      } else {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final muted = theme.typography.body.sm.copyWith(
      color: theme.colors.mutedForeground,
    );
    return Material(
      color: theme.colors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Giao không thành',
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text('Lý do', style: muted),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reason in failReasons)
                  FButton(
                    size: FButtonSizeVariant.sm,
                    mainAxisSize: MainAxisSize.min,
                    variant: _reason == reason
                        ? FButtonVariant.primary
                        : FButtonVariant.outline,
                    onPress: _submitting
                        ? null
                        : () => setState(
                            () => _reason = _reason == reason ? null : reason,
                          ),
                    child: Text(reason),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FTextField.multiline(
              control: FTextFieldControl.managed(controller: _extra),
              label: const Text('Ghi chú thêm'),
              hint: _reason == null
                  ? 'Bắt buộc nếu không chọn lý do'
                  : 'vd. Gọi 3 lần lúc 10:15, 10:25, 10:40',
              minLines: 2,
              maxLength: 400,
              enabled: !_submitting,
            ),
            const SizedBox(height: 8),
            Text(
              'Đơn vẫn ở chỗ bạn, giao lại được lần sau. Cửa hàng sẽ được báo.',
              style: muted,
            ),
            const SizedBox(height: 20),
            FButton(
              variant: FButtonVariant.destructive,
              onPress: _note.isEmpty || _submitting ? null : _submit,
              prefix: _submitting
                  ? const FCircularProgress(
                      size: FCircularProgressSizeVariant.sm,
                    )
                  : null,
              child: const Text('Báo giao không thành'),
            ),
          ],
        ),
      ),
    );
  }
}
