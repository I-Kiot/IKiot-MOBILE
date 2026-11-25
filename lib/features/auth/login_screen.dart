import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/network/api_exception.dart';
import '../../router/routes.dart';
import 'otp_challenge.dart';
import 'otp_step.dart';

/// Wireframe màn 1. Không có đăng ký: tài khoản giao hàng do cửa hàng tạo.
///
/// Cùng luồng với trang đăng nhập IKiot-FE: một ô "số điện thoại hoặc email"; tài khoản chưa xác minh email thì BE
/// gửi mã OTP và màn chuyển sang bước nhập mã ([OtpStep]) trước khi cấp phiên. Riêng app: chỉ shipper vào được
/// (`SessionUser.canUseDeliveryApp`).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  /// Có giá trị khi BE đòi mã OTP: màn hiện bước nhập mã thay cho form.
  OtpChallenge? _challenge;
  bool _noticeRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Bị đưa ra ngoài vì lý do khác người dùng tự đăng xuất (vd. vừa bị gỡ quyền giao hàng): nói lý do một lần.
    if (_noticeRead) return;
    _noticeRead = true;
    _error = AppScope.of(context).auth.takeNotice();
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Email giữ nguyên (BE tự hạ chữ thường); số điện thoại bỏ khoảng trắng người dùng gõ chen vào.
    final raw = _phone.text.trim();
    final identifier = raw.contains('@')
        ? raw
        : raw.replaceAll(RegExp(r'\s'), '');
    final password = _password.text;
    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _error = 'Nhập số điện thoại hoặc email, và mật khẩu.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final challenge = await AppScope.of(context).auth
          .login(identifier: identifier, password: password);
      // Không có thử thách: router tự chuyển sang Cần giao khi trạng thái đổi thành signedIn.
      if (challenge != null && mounted) {
        setState(() => _challenge = challenge);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FScaffold(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 48, 8, 24),
          children: [
            ..._logo(theme),
            if (_challenge case final challenge?)
              _otpStep(challenge)
            else
              ..._form(theme),
          ],
        ),
      ),
    );
  }

  Widget _otpStep(OtpChallenge challenge) {
    final auth = AppScope.of(context).auth;
    return OtpStep(
      title: 'Xác minh email',
      submitLabel: 'Xác nhận và đăng nhập',
      delivery: challenge.delivery,
      // Thành công thì router tự chuyển sang Cần giao. Không có quyền giao hàng: thử thách đã dùng xong (email vẫn được
      // xác minh, như trên web), nên về lại form và báo ở đó thay vì để người dùng nhập mã vào một phiên đã hết.
      onSubmit: (code) async {
        try {
          await auth.verifyLoginOtp(challenge.challengeToken, code);
        } on ApiException catch (error) {
          if (error.code != ApiException.deliveryOnlyCode) rethrow;
          if (mounted) {
            setState(() {
              _challenge = null;
              _error = error.userMessage;
            });
          }
        }
      },
      onResend: () => auth.resendOtp(challenge.challengeToken),
      onBack: () => setState(() => _challenge = null),
    );
  }

  List<Widget> _logo(FThemeData theme) => [
    Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        // Logo xe đẩy của IKiot-FE, tô theo theme như trang đăng nhập web (`bg-primary text-primary-foreground`).
        child: Image.asset(
          'assets/icon/logo.png',
          width: 38,
          height: 38,
          color: theme.colors.primaryForeground,
          semanticLabel: 'iKiot',
        ),
      ),
    ),
    const SizedBox(height: 20),
  ];

  List<Widget> _form(FThemeData theme) => [
    Text(
      'Đăng nhập',
      style: theme.typography.body.xl2.copyWith(fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 4),
    Text(
      'Dùng số điện thoại hoặc email cửa hàng đã cấp cho bạn.',
      style: theme.typography.body.sm.copyWith(
        color: theme.colors.mutedForeground,
      ),
    ),
    const SizedBox(height: 24),
    AutofillGroup(
      child: Column(
        children: [
          FTextField(
            control: FTextFieldControl.managed(controller: _phone),
            label: const Text('Số điện thoại hoặc email'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.username],
            enabled: !_submitting,
          ),
          const SizedBox(height: 16),
          FTextField.password(
            control: FTextFieldControl.managed(controller: _password),
            label: const Text('Mật khẩu'),
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmit: (_) => _submit(),
            enabled: !_submitting,
          ),
        ],
      ),
    ),
    Align(
      alignment: Alignment.centerRight,
      child: FButton(
        variant: FButtonVariant.ghost,
        mainAxisSize: MainAxisSize.min,
        onPress: _submitting
            ? null
            : () {
                // Lỗi của lần đăng nhập trước không còn đúng khi quay lại sau khi đặt mật khẩu mới.
                setState(() => _error = null);
                context.push(Routes.forgotPassword, extra: _phone.text.trim());
              },
        child: const Text('Quên mật khẩu?'),
      ),
    ),
    if (_error != null) ...[
      const SizedBox(height: 4),
      Text(
        _error!,
        style: theme.typography.body.sm.copyWith(
          color: theme.colors.destructive,
        ),
      ),
    ],
    const SizedBox(height: 20),
    FButton(
      onPress: _submitting ? null : _submit,
      prefix: _submitting
          ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
          : null,
      child: Text(_submitting ? 'Đang đăng nhập' : 'Đăng nhập'),
    ),
  ];
}
