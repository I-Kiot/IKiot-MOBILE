import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/toast.dart';

/// Đổi mật khẩu. Xong thì về màn đăng nhập: BE đã kết thúc mọi phiên, kể cả phiên này.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Kiểm tra ở máy trước để báo ngay; BE vẫn kiểm lại cả hai luật này.
    final error = switch ((_current.text, _next.text, _again.text)) {
      ('', _, _) => 'Nhập mật khẩu hiện tại.',
      (_, final next, _) when next.length < 6 =>
        'Mật khẩu mới cần ít nhất 6 ký tự.',
      (_, final next, final again) when next != again =>
        'Mật khẩu nhập lại không khớp.',
      _ => null,
    };
    if (error != null) return setState(() => _error = error);

    setState(() {
      _submitting = true;
      _error = null;
    });
    final scope = AppScope.of(context);
    try {
      await scope.auth.changePassword(current: _current.text, next: _next.text);
      if (mounted) {
        showSuccessToast(
          context,
          'Đã đổi mật khẩu. Đăng nhập lại bằng mật khẩu mới.',
        );
      }
      // Router tự chuyển về màn đăng nhập khi phiên kết thúc.
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.userMessage;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FScaffold(
      header: SafeArea(
        bottom: false,
        child: FHeader.nested(
          title: const Text('Đổi mật khẩu'),
          prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          FTextField.password(
            control: FTextFieldControl.managed(controller: _current),
            label: const Text('Mật khẩu hiện tại'),
            autofillHints: const [AutofillHints.password],
            enabled: !_submitting,
          ),
          const SizedBox(height: 16),
          FTextField.password(
            control: FTextFieldControl.managed(controller: _next),
            label: const Text('Mật khẩu mới'),
            description: const Text('Ít nhất 6 ký tự.'),
            autofillHints: const [AutofillHints.newPassword],
            enabled: !_submitting,
          ),
          const SizedBox(height: 16),
          FTextField.password(
            control: FTextFieldControl.managed(controller: _again),
            label: const Text('Nhập lại mật khẩu mới'),
            textInputAction: TextInputAction.done,
            onSubmit: (_) => _submit(),
            enabled: !_submitting,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.destructive,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Đổi xong bạn sẽ phải đăng nhập lại trên mọi máy.',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 20),
          FButton(
            onPress: _submitting ? null : _submit,
            prefix: _submitting
                ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
                : null,
            child: const Text('Đổi mật khẩu'),
          ),
        ],
      ),
    );
  }
}
