import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

void showSuccessToast(BuildContext context, String message) => showFToast(
  context: context,
  title: Text(message),
  icon: const Icon(FLucideIcons.circleCheck),
);

void showErrorToast(BuildContext context, String message) => showFToast(
  context: context,
  variant: FToastVariant.destructive,
  title: Text(message),
  icon: const Icon(FLucideIcons.circleAlert),
);
