import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/option_sheet.dart';
import '../../core/widgets/toast.dart';
import '../auth/session_user.dart';

enum _AvatarAction { camera, gallery, remove }

/// Ảnh đại diện ở đầu màn Tôi. Bấm vào để chụp, chọn từ thư viện, hoặc xoá ảnh.
///
/// Trong lúc xử lý và tải lên, avatar có lớp phủ vòng quay và không bấm được, để không gửi hai ảnh chồng nhau.
class AvatarEditor extends StatefulWidget {
  const AvatarEditor({super.key, required this.user, this.size = 64});

  final SessionUser? user;
  final double size;

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  final _picker = ImagePicker();
  bool _busy = false;

  bool get _hasAvatar => widget.user?.avatarUrl?.isNotEmpty ?? false;

  Future<void> _edit() async {
    final action = await showOptionSheet<_AvatarAction?>(
      context,
      title: 'Ảnh đại diện',
      selected: null,
      options: [
        (_AvatarAction.camera, 'Chụp ảnh'),
        (_AvatarAction.gallery, 'Chọn từ thư viện'),
        if (_hasAvatar) (_AvatarAction.remove, 'Xoá ảnh'),
      ],
    );
    if (action == null || !mounted) return;
    final auth = AppScope.of(context).auth;

    setState(() => _busy = true);
    try {
      if (action == _AvatarAction.remove) {
        await auth.removeAvatar();
        if (mounted) showSuccessToast(context, 'Đã xoá ảnh đại diện');
        return;
      }
      // 512px là đủ cho avatar và nhẹ để tải lên qua 4G; camera trước vì đây là ảnh chân dung.
      final picked = await _picker.pickImage(
        source: action == _AvatarAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      await auth.changeAvatar(picked.path);
      if (mounted) showSuccessToast(context, 'Đã đổi ảnh đại diện');
    } on ApiException catch (error) {
      if (mounted) showErrorToast(context, error.userMessage);
    } catch (_) {
      // Không mở được camera / thư viện (bị từ chối quyền).
      if (mounted) {
        showErrorToast(context, 'Không mở được camera hoặc thư viện ảnh.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final user = widget.user;
    final initials = Text(user?.initials ?? '?');
    final avatar = _hasAvatar
        ? FAvatar(
            image: NetworkImage(user!.avatarUrl!),
            size: widget.size,
            fallback: initials,
          )
        : FAvatar.raw(size: widget.size, child: initials);

    return Semantics(
      button: true,
      label: 'Đổi ảnh đại diện',
      child: FTappable(
        onPress: _busy || user == null ? null : _edit,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              if (_busy)
                Container(
                  // Phủ sáng theo nền chứ không phủ đen: vòng quay của forui màu chữ (tối ở giao diện sáng),
                  // nên trên lớp đen gần như không thấy.
                  decoration: BoxDecoration(
                    color: theme.colors.background.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const FCircularProgress(
                    size: FCircularProgressSizeVariant.sm,
                  ),
                ),
              // Huy hiệu máy ảnh: cho biết avatar bấm được.
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: theme.colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colors.background,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    FLucideIcons.camera,
                    size: 12,
                    color: theme.colors.primaryForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
