import 'dart:io';

import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/toast.dart';
import 'deliveries_repository.dart';
import 'shipment_detail.dart';
import '../../core/widgets/app_card.dart';

/// Kết quả của sheet: chi tiết mới sau khi giao, hoặc [stale] = dữ liệu đã cũ, màn phải tải lại.
typedef DeliverResult = ({ShipmentDetail? delivered, bool stale});

/// Wireframe màn 4. Mở bằng [showDeliverSheet].
///
/// Số tiền không sửa được: BE chỉ nhận đúng số còn phải thu (chốt 2026-10-06), nên ô sửa được chỉ sinh lỗi.
/// Ảnh tải lên ngay khi chụp, để lúc bấm xác nhận không phải chờ thêm.
Future<DeliverResult?> showDeliverSheet(
  BuildContext context, {
  required ShipmentDetail shipment,
  required DeliveriesRepository repository,
}) => showFSheet<DeliverResult>(
  context: context,
  side: FLayout.btt,
  useRootNavigator: true,
  mainAxisMaxRatio: 0.92,
  builder: (context) =>
      _DeliverSheet(shipment: shipment, repository: repository),
);

class _DeliverSheet extends StatefulWidget {
  const _DeliverSheet({required this.shipment, required this.repository});

  final ShipmentDetail shipment;
  final DeliveriesRepository repository;

  @override
  State<_DeliverSheet> createState() => _DeliverSheetState();
}

class _Photo {
  _Photo(this.file);
  final File file;
  String? url;
  bool failed = false;
}

class _DeliverSheetState extends State<_DeliverSheet> {
  final _note = TextEditingController();
  final _picker = ImagePicker();
  final List<_Photo> _photos = [];
  late String _method = _nothingDue
      ? CollectionMethod.none
      : CollectionMethod.cash;
  bool? _qrAvailable;
  bool _submitting = false;

  /// Đang chờ plugin trả ảnh. Ảnh chụp xong vẫn mất vài giây để thu nhỏ trước khi về tới đây,
  /// nên phải có ô "đang xử lý", không thì người dùng tưởng chụp hỏng và chụp lại.
  bool _processing = false;

  bool get _nothingDue => widget.shipment.amountDue == 0;
  bool get _uploading => _photos.any((p) => p.url == null && !p.failed);
  List<String> get _uploadedUrls => [
    for (final p in _photos)
      if (p.url != null) p.url!,
  ];
  bool get _canSubmit =>
      !_submitting && !_processing && !_uploading && _uploadedUrls.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!_nothingDue) {
      widget.repository.canCollectByQr().then((value) {
        if (mounted) setState(() => _qrAvailable = value);
      });
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(ImageSource source) async {
    setState(() => _processing = true);
    XFile? picked;
    try {
      // 1600px, chất lượng 75: đủ đọc được nhãn hàng, và dưới giới hạn 5MB của /uploads.
      picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 75,
      );
    } catch (_) {
      // Không mở được camera / thư viện (bị từ chối quyền): báo rồi thôi.
      if (mounted) {
        showErrorToast(context, 'Không mở được camera hoặc thư viện ảnh.');
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
    if (picked == null || !mounted) return;
    final photo = _Photo(File(picked.path));
    setState(() => _photos.add(photo));
    try {
      final url = await widget.repository.uploadPhoto(picked.path);
      if (mounted) setState(() => photo.url = url);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => photo.failed = true);
      showErrorToast(context, error.userMessage);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    final note = _note.text.trim();
    try {
      final delivered = await widget.repository.deliver(
        widget.shipment.id,
        proofPhotoUrls: _uploadedUrls,
        paymentMethod: _method,
        collectedAmount: _nothingDue ? 0 : widget.shipment.amountDue,
        note: note.isEmpty ? null : note,
      );
      if (mounted) {
        Navigator.of(context)
            .pop<DeliverResult>((delivered: delivered, stale: false));
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

  String get _submitLabel {
    if (_submitting) return 'Đang gửi';
    if (_nothingDue) return 'Xác nhận đã giao';
    if (_method == CollectionMethod.qr) return 'Đã giao, hiện mã QR';
    return 'Đã nhận ${formatMoney(widget.shipment.amountDue)}';
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
              'Xác nhận đã giao',
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text('Ảnh giao hàng (bắt buộc)', style: muted),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final photo in _photos)
                  _PhotoThumb(
                    photo: photo,
                    onRemove: _submitting
                        ? null
                        : () => setState(() => _photos.remove(photo)),
                  ),
                if (_processing) const _ProcessingThumb(),
                if (_photos.length < 10 && !_processing) ...[
                  _AddPhotoButton(
                    icon: FLucideIcons.camera,
                    label: 'Chụp',
                    onPress: _submitting
                        ? null
                        : () => _takePhoto(ImageSource.camera),
                  ),
                  _AddPhotoButton(
                    icon: FLucideIcons.image,
                    label: 'Thư viện',
                    onPress: _submitting
                        ? null
                        : () => _takePhoto(ImageSource.gallery),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            if (_nothingDue)
              AppCard(
                child: Text(
                  'Đơn đã trả đủ, không thu thêm tiền.',
                  style: theme.typography.body.sm,
                ),
              )
            else ...[
              Text('Cách thu tiền', style: muted),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _methodButton(
                      CollectionMethod.cash,
                      'Tiền mặt',
                      FLucideIcons.banknote,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _methodButton(
                      CollectionMethod.qr,
                      'QR chuyển khoản',
                      FLucideIcons.qrCode,
                      enabled: _qrAvailable != false,
                    ),
                  ),
                ],
              ),
              if (_qrAvailable == false) ...[
                const SizedBox(height: 6),
                Text('Cửa hàng chưa bật nhận tiền bằng QR.', style: muted),
              ],
              const SizedBox(height: 16),
              Text('Số tiền thu', style: muted),
              const SizedBox(height: 8),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatMoney(widget.shipment.amountDue),
                        style: theme.typography.body.xl.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      FLucideIcons.lock,
                      size: 18,
                      color: theme.colors.mutedForeground,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Phải thu đúng số còn lại của đơn. Khách trả khác số này thì báo cửa hàng.',
                style: muted,
              ),
            ],
            const SizedBox(height: 16),
            FTextField(
              control: FTextFieldControl.managed(controller: _note),
              label: const Text('Ghi chú'),
              hint: 'Không bắt buộc',
              maxLength: 500,
              enabled: !_submitting,
            ),
            const SizedBox(height: 20),
            FButton(
              onPress: _canSubmit ? _submit : null,
              prefix: _submitting
                  ? const FCircularProgress(
                      size: FCircularProgressSizeVariant.sm,
                    )
                  : null,
              child: Text(
                _processing
                    ? 'Đang xử lý ảnh'
                    : _uploading
                    ? 'Đang tải ảnh lên'
                    : _submitLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodButton(
    String method,
    String label,
    IconData icon, {
    bool enabled = true,
  }) => FButton(
    variant: _method == method
        ? FButtonVariant.primary
        : FButtonVariant.outline,
    onPress: enabled && !_submitting
        ? () => setState(() => _method = method)
        : null,
    prefix: Icon(icon),
    child: Text(label),
  );
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo, required this.onRemove});

  final _Photo photo;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(photo.file, fit: BoxFit.cover),
          ),
          if (photo.url == null)
            Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: photo.failed
                  ? const Icon(
                      FLucideIcons.triangleAlert,
                      color: Colors.white,
                      size: 20,
                    )
                  : const FCircularProgress(
                      size: FCircularProgressSizeVariant.sm,
                    ),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: theme.colors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  FLucideIcons.x,
                  size: 14,
                  color: theme.colors.foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({
    required this.icon,
    required this.label,
    required this.onPress,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FTappable(
      onPress: onPress,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: theme.colors.mutedForeground),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô tạm trong lúc ảnh vừa chụp đang được thu nhỏ.
class _ProcessingThumb extends StatelessWidget {
  const _ProcessingThumb();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: theme.colors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FCircularProgress(size: FCircularProgressSizeVariant.sm),
          const SizedBox(height: 4),
          Text(
            'Xử lý…',
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
