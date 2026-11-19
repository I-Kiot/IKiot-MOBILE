import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// Hiện trong lúc [AuthController.restore] đọc token và gọi `/auth/me`.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const FScaffold(child: Center(child: FCircularProgress()));
}
