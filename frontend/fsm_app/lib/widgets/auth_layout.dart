import 'package:flutter/material.dart';

import 'app_logo.dart';

/// Shared layout for auth screens: centred, scrollable, and width-capped so the
/// form looks right on phones as well as wide Flutter Web windows.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AppLogo()),
        const SizedBox(height: 20),
        Text(title, textAlign: TextAlign.center, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        child,
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              // On wide screens, frame the form in a card; on phones, use the full width.
              child: isWide ? Card(child: Padding(padding: const EdgeInsets.all(32), child: content)) : content,
            ),
          ),
        ),
      ),
    );
  }
}
