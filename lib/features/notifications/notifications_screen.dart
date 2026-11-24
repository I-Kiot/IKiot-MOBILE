import 'dart:async';

import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/toast.dart';
import '../../router/routes.dart';
import 'app_notification.dart';
import 'notifications_repository.dart';

/// Hộp thông báo, mở từ chuông ở màn Cần giao. Bấm một thông báo giao hàng thì mở lần giao đó.
///
/// Realtime: BE phát `notification` vào phòng `user:<id>` mỗi khi có thông báo mới cho mình. Màn tải lại trang
/// đầu và chèn thông báo mới lên trên, giữ nguyên những trang đã cuộn tới (không tải lại từ đầu, không nhảy cuộn).
/// Socket nối lại sau khi đứt cũng làm vậy, vì thông báo đến lúc mất kết nối không được phát lại.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsRepository _repository = NotificationsRepository(
    AppScope.of(context).api,
  );
  final _scroll = ScrollController();
  final List<AppNotification> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  ApiException? _error;
  final List<StreamSubscription<void>> _live = [];
  Timer? _liveTimer;

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
    if (_live.isEmpty) {
      final realtime = AppScope.of(context).realtime;
      _live
        ..add(realtime.notifications.listen((_) => _scheduleFetchNewest()))
        ..add(realtime.reconnected.listen((_) => _scheduleFetchNewest()));
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    for (final sub in _live) {
      sub.cancel();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _page = 0;
    _hasMore = true;
    _items.clear();
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await _repository.list(page: _page + 1);
      if (!mounted) return;
      setState(() {
        // Thông báo mới chèn lên đầu làm trang phía server trượt xuống, nên trang sau có thể lặp dòng đã hiện.
        final shown = {for (final n in _items) n.id};
        _items.addAll(page.items.where((n) => !shown.contains(n.id)));
        _page = page.page;
        _hasMore = page.hasMore;
        _error = null;
      });
      AppScope.of(context).counts.unread =
          (page.raw['unreadCount'] as num?)?.toInt() ?? 0;
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Gộp các sự kiện dồn dập (nhiều thông báo cùng lúc) thành một lần gọi.
  void _scheduleFetchNewest() {
    _liveTimer?.cancel();
    _liveTimer = Timer(const Duration(milliseconds: 400), _fetchNewest);
  }

  /// Tải trang đầu và hợp vào danh sách đang hiện: dòng mới lên đầu, dòng đã có thì cập nhật (vd. đã đọc ở máy khác).
  Future<void> _fetchNewest() async {
    if (!mounted) return;
    // Chưa tải xong lần đầu, hoặc đang lỗi trắng màn: tải lại cả danh sách là đủ.
    if (_page == 0) {
      if (!_loading) _reload();
      return;
    }
    try {
      final page = await _repository.list(page: 1);
      if (!mounted) return;
      final fresh = {for (final n in page.items) n.id: n};
      final shown = {for (final n in _items) n.id};
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          final updated = fresh[_items[i].id];
          if (updated != null) _items[i] = updated;
        }
        _items.insertAll(0, page.items.where((n) => !shown.contains(n.id)));
        _error = null;
      });
      AppScope.of(context).counts.unread =
          (page.raw['unreadCount'] as num?)?.toInt() ?? 0;
    } on ApiException {
      // Lặng lẽ bỏ qua: danh sách cũ vẫn đúng, kéo xuống để tải lại khi có mạng.
    }
  }

  Future<void> _open(AppNotification item) async {
    if (!item.isRead) {
      final counts = AppScope.of(context).counts;
      setState(
        () => _items[_items.indexOf(item)] = item.copyWith(isRead: true),
      );
      counts.unread = (counts.unread - 1).clamp(0, 1 << 30);
      _repository.markRead(item.id).ignore();
    }
    final shipmentId = item.shipmentId;
    if (shipmentId != null) await context.push(Routes.delivery(shipmentId));
  }

  Future<void> _markAllRead() async {
    try {
      await _repository.markAllRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].copyWith(isRead: true);
        }
      });
      AppScope.of(context).counts.unread = 0;
    } on ApiException catch (error) {
      if (mounted) showErrorToast(context, error.userMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: SafeArea(
        bottom: false,
        child: FHeader.nested(
          title: const Text('Thông báo'),
          prefixes: [FHeaderAction.back(onPress: () => context.pop())],
          suffixes: [
            if (_items.any((n) => !n.isRead))
              FHeaderAction(
                icon: const Icon(FLucideIcons.checkCheck),
                onPress: _markAllRead,
              ),
          ],
        ),
      ),
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_items.isEmpty && _loading) {
      return const Center(child: FCircularProgress());
    }
    if (_items.isEmpty && _error != null) {
      return EmptyState(
        icon: FLucideIcons.wifiOff,
        title: 'Chưa tải được thông báo',
        message: _error!.userMessage,
        action: FButton(
          variant: FButtonVariant.outline,
          mainAxisSize: MainAxisSize.min,
          onPress: _reload,
          child: const Text('Thử lại'),
        ),
      );
    }
    final theme = context.theme;
    return RefreshIndicator(
      onRefresh: _reload,
      child: _items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: FLucideIcons.bell,
                  title: 'Chưa có thông báo',
                  message: 'Khi được giao đơn mới, bạn sẽ thấy ở đây.',
                ),
              ],
            )
          : ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _items.length + (_hasMore ? 1 : 0),
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: theme.colors.border),
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: FCircularProgress()),
                  );
                }
                final item = _items[index];
                return FTappable(
                  onPress: () => _open(item),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 10),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: item.isRead
                                  ? Colors.transparent
                                  : theme.colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.typography.body.sm.copyWith(
                                  fontWeight: item.isRead
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.description,
                                style: theme.typography.body.sm.copyWith(
                                  color: theme.colors.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'HH:mm dd/MM/yyyy',
                                  'vi',
                                ).format(item.createdAt),
                                style: theme.typography.body.xs.copyWith(
                                  color: theme.colors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
