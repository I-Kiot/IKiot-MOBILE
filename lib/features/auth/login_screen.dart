import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/network/api_exception.dart';

/// Wireframe màn 1. Không có đăng ký: tài khoản giao hàng do cửa hàng tạo.
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

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone.text.replaceAll(RegExp(r'\s'), '');
    final password = _password.text;
    if (phone.isEmpty || password.isEmpty) {
      setState(() => _error = 'Nhập số điện thoại và mật khẩu.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AppScope.of(context).auth
          .login(phoneNumber: phone, password: password);
      // Router tự chuyển sang Cần giao khi trạng thái đổi thành signedIn.
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
            Text(
              'Đăng nhập',
              style: theme.typography.body.xl2.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dùng số điện thoại cửa hàng đã cấp cho bạn.',
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
                    label: const Text('Số điện thoại'),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                    ],
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.destructive,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FButton(
              onPress: _submitting ? null : _submit,
              prefix: _submitting
                  ? const FCircularProgress(
                      size: FCircularProgressSizeVariant.sm,
                    )
                  : null,
              child: Text(_submitting ? 'Đang đăng nhập' : 'Đăng nhập'),
            ),
          ],
        ),
      ),
    );
  }
}
