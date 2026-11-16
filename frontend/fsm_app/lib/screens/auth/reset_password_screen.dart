import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/password_field.dart';
import '../../widgets/state_views.dart';

/// Enter the emailed code + a new password. Serves both "forgot password" and
/// new employees setting their first password. Success logs the user in.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resetPassword(email: _email.text, code: _code.text, password: _password.text);
      // The router redirects to the dashboard once the auth state holds a user.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final emailError = Validators.email(_email.text);
    if (emailError != null) {
      showSnack(context, emailError, error: true);
      return;
    }
    setState(() => _resending = true);
    try {
      await ref.read(authServiceProvider).forgotPassword(_email.text);
      if (mounted) showSnack(context, 'If an account exists, a new code has been sent.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _resending;
    return AuthLayout(
      title: 'Set a new password',
      subtitle: 'Enter the 6-digit code from your email',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null && _error!.fieldErrors.isEmpty) ...[
                ErrorBanner(message: _error!.message),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  errorText: _error?.fieldErrors['email'],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '') ? null : 'Enter the 6-digit code',
                style: const TextStyle(letterSpacing: 6, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Code',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  errorText: _error?.fieldErrors['code'],
                ),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: 'New password',
                validator: Validators.newPassword,
                errorText: _error?.fieldErrors['password'],
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                label: 'Confirm new password',
                validator: Validators.confirmPassword(() => _password.text),
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              LoadingButton(label: 'Set password & sign in', loading: _loading, onPressed: _submit),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(onPressed: busy ? null : _resend, child: const Text('Resend code')),
                  TextButton(
                    onPressed: busy ? null : () => context.go(AppRoutes.login),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
