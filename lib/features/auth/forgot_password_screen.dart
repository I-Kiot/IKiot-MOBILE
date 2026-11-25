import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/toast.dart';
import 'otp_challenge.dart';
import 'otp_step.dart';

/// Quên mật khẩu qua email, ba bước như `forgot-password-form.tsx` của IKiot-FE: số điện thoại hoặc email → mã OTP gửi
/// về email → mật khẩu mới. Mã đặt lại chỉ giữ trong state và dùng một lần. Không chặn theo quyền giao hàng ở đây:
/// đặt lại mật khẩu là việc của tài khoản, còn ai được vào app thì màn đăng nhập quyết định.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialIdentifier});

  /// Ô số điện thoại / email đang gõ ở màn đăng nhập, điền sẵn cho đỡ gõ lại.
  final String? initialIdentifier;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _identifier = TextEditingController(
    text: widget.initialIdentifier ?? '',
  );
  final _password = TextEditingController();
  final _again = TextEditingController();

  OtpChallenge? _challenge;
  String? _resetToken;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.userMessage;
        // Mã đặt lại hết hạn / đã dùng: phải xin mã OTP mới từ đầu.
        if (error.isResetTokenDead) {
          _resetToken = null;
          _challenge = null;
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _sendCode() {
    final raw = _identifier.text.trim();
    final identifier = raw.contains('@')
        ? raw
        : raw.replaceAll(RegExp(r'\s'), '');
    if (identifier.isEmpty) {
      return setState(() => _error = 'Nhập số điện thoại hoặc email.');
    }
    final auth = AppScope.of(context).auth;
    _run(() async {
      final challenge = await auth.sendForgotPasswordOtp(identifier);
      if (mounted) setState(() => _challenge = challenge);
    });
  }

  void _resetPassword() {
    // Kiểm ở máy cho nhanh, cùng luật với web; BE vẫn kiểm lại độ dài.
    final error = switch ((_password.text, _again.text)) {
      (final next, _) when next.length < 6 =>
        'Mật khẩu mới cần ít nhất 6 ký tự.',
      (final next, final again) when next != again =>
        'Mật khẩu nhập lại không khớp.',
      _ => null,
    };
    if (error != null) return setState(() => _error = error);
    final auth = AppScope.of(context).auth;
    final token = _resetToken!;
    _run(() async {
      await auth.resetPassword(token, _password.text);
      if (!mounted) return;
      showSuccessToast(
        context,
        'Đã đặt lại mật khẩu. Đăng nhập bằng mật khẩu mới.',
      );
      context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: SafeArea(
        bottom: false,
        child: FHeader.nested(
          title: const Text('Quên mật khẩu'),
          prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: switch ((_challenge, _resetToken)) {
          (_, final String _) => _passwordStep(context),
          (final OtpChallenge challenge, _) => [_otpStep(challenge)],
          _ => _identifierStep(context),
        },
      ),
    );
  }

  Widget _otpStep(OtpChallenge challenge) {
    final auth = AppScope.of(context).auth;
    return OtpStep(
      title: 'Nhập mã xác minh',
      submitLabel: 'Xác nhận',
      delivery: challenge.delivery,
      onSubmit: (code) async {
        final token = await auth.verifyForgotPasswordOtp(
          challenge.challengeToken,
          code,
        );
        if (mounted) setState(() => _resetToken = token);
      },
      onResend: () => auth.resendOtp(challenge.challengeToken),
      onBack: () => setState(() => _challenge = null),
    );
  }

  List<Widget> _identifierStep(BuildContext context) {
    final theme = context.theme;
    return [
      Text(
        'Nhập số điện thoại hoặc email của tài khoản. Mã xác minh sẽ được gửi tới email của tài khoản.',
        style: theme.typography.body.sm.copyWith(
          color: theme.colors.mutedForeground,
        ),
      ),
      const SizedBox(height: 20),
      FTextField(
        control: FTextFieldControl.managed(controller: _identifier),
        label: const Text('Số điện thoại hoặc email'),
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.username],
        onSubmit: (_) => _sendCode(),
        enabled: !_submitting,
      ),
      ..._errorAndButton(context, 'Gửi mã xác minh', _sendCode),
    ];
  }

  List<Widget> _passwordStep(BuildContext context) {
    final theme = context.theme;
    return [
      Text(
        'Đặt mật khẩu mới',
        style: theme.typography.body.xl2.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        'Email đã được xác minh. Nhập mật khẩu mới cho tài khoản.',
        style: theme.typography.body.sm.copyWith(
          color: theme.colors.mutedForeground,
        ),
      ),
      const SizedBox(height: 20),
      FTextField.password(
        control: FTextFieldControl.managed(controller: _password),
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
        onSubmit: (_) => _resetPassword(),
        enabled: !_submitting,
      ),
      const SizedBox(height: 12),
      Text(
        'Đặt lại xong, mọi máy đang đăng nhập tài khoản này sẽ phải đăng nhập lại.',
        style: theme.typography.body.sm.copyWith(
          color: theme.colors.mutedForeground,
        ),
      ),
      ..._errorAndButton(context, 'Đặt lại mật khẩu', _resetPassword),
    ];
  }

  List<Widget> _errorAndButton(
    BuildContext context,
    String label,
    VoidCallback onPress,
  ) {
    final theme = context.theme;
    return [
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.destructive,
          ),
        ),
      ],
      const SizedBox(height: 20),
      FButton(
        onPress: _submitting ? null : onPress,
        prefix: _submitting
            ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
            : null,
        child: Text(label),
      ),
    ];
  }
}
