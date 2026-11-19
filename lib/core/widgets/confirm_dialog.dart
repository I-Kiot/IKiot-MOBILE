import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// Hộp xác nhận hai nút xếp dọc (nút chính trên, Huỷ dưới), vừa ngón cái trên điện thoại.
/// Trả `true` khi người dùng bấm nút chính.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final confirmed = await showFDialog<bool>(
    context: context,
    builder: (context, style, animation) => FDialog(
      style: style,
      animation: animation,
      builder: (context, style) {
        final theme = context.theme;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: theme.typography.body.lg.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 20),
              FButton(
                variant: destructive
                    ? FButtonVariant.destructive
                    : FButtonVariant.primary,
                onPress: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
              const SizedBox(height: 8),
              FButton(
                variant: FButtonVariant.outline,
                onPress: () => Navigator.of(context).pop(false),
                child: const Text('Huỷ'),
              ),
            ],
          ),
        );
      },
    ),
  );
  return confirmed ?? false;
}
