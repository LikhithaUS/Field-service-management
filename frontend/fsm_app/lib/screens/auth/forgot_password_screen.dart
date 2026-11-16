import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/utils/validators.dart';
import '../../providers/service_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_button.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _goToReset() => context.go(AppRoutes.resetPasswordFor(_email.text.trim()));

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).forgotPassword(_email.text);
      if (mounted) _goToReset();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Forgot password?',
      subtitle: "Enter your account email and we'll send you a 6-digit code",
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[ErrorBanner(message: _error!.message), const SizedBox(height: 16)],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 24),
            LoadingButton(label: 'Send code', loading: _loading, onPressed: _submit),
            const SizedBox(height: 12),
            // New employees arrive here with a setup code from their welcome email.
            TextButton(onPressed: _loading ? null : _goToReset, child: const Text('I already have a code')),
            TextButton(
              onPressed: _loading ? null : () => context.go(AppRoutes.login),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
