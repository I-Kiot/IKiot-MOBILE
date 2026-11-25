import 'dart:async';

import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/env.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/toast.dart';
import 'otp_challenge.dart';

const _otpLength = 6;

/// Bước nhập mã OTP gửi qua email, dùng chung cho đăng nhập lần đầu và quên mật khẩu. Cùng hành vi với `OtpStep` của
/// IKiot-FE (`src/components/otp-step.tsx`): hiện email đã che, đếm ngược hạn mã, "Gửi lại mã" khoá theo
/// `resendAfterSeconds`, báo số lần thử còn lại, phiên xác minh hỏng thì quay về bước trước.
///
/// Khác web một điểm: nhập đủ 6 số là tự xác nhận, vì trên điện thoại bàn phím số che mất nút.
class OtpStep extends StatefulWidget {
  const OtpStep({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.delivery,
    required this.onSubmit,
    required this.onResend,
    required this.onBack,
  });

  final String title;
  final String submitLabel;
  final OtpDelivery delivery;

  /// Gọi BE xác thực mã; ném [ApiException] nếu sai. Thành công thì màn cha tự chuyển bước.
  final Future<void> Function(String otpCode) onSubmit;
  final Future<OtpDelivery> Function() onResend;

  /// Quay lại bước trước (cũng dùng khi phiên xác minh không còn hợp lệ).
  final VoidCallback onBack;

  @override
  State<OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends State<OtpStep> {
  final _code = TextEditingController();

  /// Ô mã bị khoá trong lúc gửi nên mất focus; mã sai thì đặt focus lại để gõ tiếp ngay, không phải chạm lại vào ô.
  final _focus = FocusNode();
  late OtpDelivery _delivery = widget.delivery;
  DateTime _sentAt = DateTime.now();
  Timer? _clock;
  bool _submitting = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (Env.otpBypass) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _submit('DEV_BYPASS'),
      );
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  int _secondsLeft(int total) {
    final left = total - DateTime.now().difference(_sentAt).inSeconds;
    return left < 0 ? 0 : left;
  }

  Future<void> _submit(String code) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(code);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isOtpChallengeDead) {
        showErrorToast(context, error.userMessage);
        return widget.onBack();
      }
      _code.clear();
      setState(() {
        _error = error.code == 'OTP_INVALID' && error.attemptsLeft != null
            ? '${error.userMessage} Còn ${error.attemptsLeft} lần thử.'
            : error.userMessage;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    // Ô vừa được mở khoá ở setState trên nhưng chưa vẽ lại; ô đang khoá không nhận focus, nên đợi khung hình sau.
    if (mounted && _error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final next = await widget.onResend();
      if (!mounted) return;
      _code.clear();
      setState(() {
        _delivery = next;
        _sentAt = DateTime.now();
      });
      showSuccessToast(context, 'Đã gửi lại mã OTP.');
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isOtpChallengeDead) {
        showErrorToast(context, error.userMessage);
        return widget.onBack();
      }
      setState(() => _error = error.userMessage);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String _clockText(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final busy = _submitting || _resending;
    final expiresIn = _secondsLeft(_delivery.expiresInSeconds);
    final resendIn = _secondsLeft(_delivery.resendAfterSeconds);
    final muted = theme.typography.body.sm.copyWith(
      color: theme.colors.mutedForeground,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: theme.typography.body.xl2.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            text: 'Nhập mã gồm 6 chữ số đã gửi đến email ',
            children: [
              TextSpan(
                text: _delivery.sentTo,
                style: TextStyle(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          style: muted,
        ),
        const SizedBox(height: 24),
        FTextField(
          control: FTextFieldControl.managed(
            controller: _code,
            onChange: (value) {
              if (value.text.length == _otpLength && !busy) {
                _submit(value.text);
              }
            },
          ),
          focusNode: _focus,
          label: const Text('Mã OTP'),
          hint: '000000',
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: !Env.otpBypass,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: _otpLength,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !busy,
        ),
        const SizedBox(height: 8),
        Text(
          expiresIn == 0
              ? 'Mã đã hết hạn. Gửi lại mã mới.'
              : 'Mã hết hạn sau ${_clockText(expiresIn)}',
          style: expiresIn == 0
              ? theme.typography.body.sm.copyWith(
                  color: theme.colors.destructive,
                )
              : muted,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.destructive,
            ),
          ),
        ],
        const SizedBox(height: 24),
        FButton(
          onPress: busy || _code.text.length < _otpLength
              ? null
              : () => _submit(_code.text),
          prefix: _submitting
              ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
              : null,
          child: Text(_submitting ? 'Đang xác thực' : widget.submitLabel),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FButton(
              variant: FButtonVariant.ghost,
              mainAxisSize: MainAxisSize.min,
              onPress: busy ? null : widget.onBack,
              child: const Text('Quay lại'),
            ),
            const Spacer(),
            FButton(
              variant: FButtonVariant.ghost,
              mainAxisSize: MainAxisSize.min,
              onPress: busy || resendIn > 0 ? null : _resend,
              child: Text(
                _resending
                    ? 'Đang gửi lại'
                    : resendIn > 0
                    ? 'Gửi lại mã (${resendIn}s)'
                    : 'Gửi lại mã',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
