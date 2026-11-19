import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// Sheet chọn một trong vài lựa chọn (giao diện, app bản đồ). Trả lựa chọn mới, `null` khi đóng.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  required T selected,
}) => showFSheet<T>(
  context: context,
  side: FLayout.btt,
  useRootNavigator: true,
  builder: (context) {
    final theme = context.theme;
    return Material(
      color: theme.colors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
              const SizedBox(height: 12),
              FTileGroup(
                children: [
                  for (final (value, label) in options)
                    FTile(
                      title: Text(label),
                      suffix: value == selected
                          ? const Icon(FLucideIcons.check)
                          : null,
                      onPress: () => Navigator.of(context).pop(value),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  },
);
