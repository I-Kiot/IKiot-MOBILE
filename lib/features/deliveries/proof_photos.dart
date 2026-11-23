import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/app_card.dart';

/// Thẻ "Đã giao" ở màn chi tiết: giờ giao và ảnh bằng chứng. Thay chỗ thẻ "Còn phải thu" khi đơn đã giao xong
/// tiền, vì lúc đó điều shipper (hay cửa hàng hỏi lại) cần xem là "đã giao lúc nào, giao ra sao".
class DeliveredCard extends StatelessWidget {
  const DeliveredCard({
    super.key,
    required this.deliveredAt,
    required this.photoUrls,
  });

  final DateTime? deliveredAt;
  final List<String> photoUrls;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final muted = theme.typography.body.sm.copyWith(
      color: theme.colors.mutedForeground,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                FLucideIcons.circleCheck,
                size: 20,
                color: theme.colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deliveredAt == null
                      ? 'Đã giao'
                      : 'Đã giao lúc ${DateFormat('HH:mm, dd/MM/yyyy', 'vi').format(deliveredAt!)}',
                  style: theme.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            photoUrls.isEmpty
                ? 'Ảnh bằng chứng'
                : 'Ảnh bằng chứng (${photoUrls.length})',
            style: muted,
          ),
          const SizedBox(height: 8),
          if (photoUrls.isEmpty)
            Text('Không có ảnh bằng chứng.', style: theme.typography.body.sm)
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: photoUrls.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) => Semantics(
                button: true,
                label: 'Xem ảnh bằng chứng ${index + 1}',
                child: FTappable(
                  onPress: () => openProofViewer(context, photoUrls, index),
                  child: Hero(
                    tag: _heroTag(photoUrls[index], index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _NetworkPhoto(
                        url: photoUrls[index],
                        fit: BoxFit.cover,
                      ),
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

String _heroTag(String url, int index) => 'proof-$index-$url';

/// Xem ảnh toàn màn: nền đen, vuốt ngang qua ảnh khác, chụm hai ngón để phóng to.
Future<void> openProofViewer(
  BuildContext context,
  List<String> urls,
  int initial,
) => Navigator.of(context, rootNavigator: true).push(
  PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black,
    pageBuilder: (context, animation, secondary) => FadeTransition(
      opacity: animation,
      child: _ProofViewer(urls: urls, initial: initial),
    ),
  ),
);

class _ProofViewer extends StatefulWidget {
  const _ProofViewer({required this.urls, required this.initial});

  final List<String> urls;
  final int initial;

  @override
  State<_ProofViewer> createState() => _ProofViewerState();
}

class _ProofViewerState extends State<_ProofViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Hero(
                    tag: _heroTag(widget.urls[i], i),
                    child: _NetworkPhoto(
                      url: widget.urls[i],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(FLucideIcons.x, color: Colors.white),
                tooltip: 'Đóng',
              ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Text(
                    '${_index + 1}/${widget.urls.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ảnh mạng có trạng thái đang tải và lỗi (mất sóng, link Cloudinary hỏng), không để ô trống trơn.
class _NetworkPhoto extends StatelessWidget {
  const _NetworkPhoto({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Image.network(
      url,
      fit: fit,
      width: fit == BoxFit.cover ? double.infinity : null,
      height: fit == BoxFit.cover ? double.infinity : null,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : ColoredBox(
              color: theme.colors.muted,
              child: const Center(
                child: FCircularProgress(size: FCircularProgressSizeVariant.sm),
              ),
            ),
      errorBuilder: (context, error, stack) => ColoredBox(
        color: theme.colors.muted,
        child: Center(
          child: Icon(
            FLucideIcons.imageOff,
            color: theme.colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
