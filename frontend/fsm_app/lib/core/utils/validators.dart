/// Form validators. Rules mirror the backend so users get instant feedback,
/// but the backend still validates everything (never trust the client).
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_email.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  /// Same rules as the backend. Any characters are allowed; these are the minimums.
  static final List<PasswordRule> passwordRules = [
    PasswordRule('at least 8 characters', (v) => v.length >= 8),
    PasswordRule('an uppercase letter (A-Z)', (v) => RegExp(r'[A-Z]').hasMatch(v)),
    PasswordRule('a lowercase letter (a-z)', (v) => RegExp(r'[a-z]').hasMatch(v)),
    PasswordRule('a number (0-9)', (v) => RegExp(r'\d').hasMatch(v)),
    PasswordRule('a special character (e.g. ! @ # \$ %)', (v) => RegExp(r'[^A-Za-z0-9]').hasMatch(v)),
  ];

  /// Lists every missing requirement at once, not just the first.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length > 128) return 'Password must be at most 128 characters';
    final missing = passwordRules.where((r) => !r.isMetBy(value)).map((r) => r.label).toList();
    if (missing.isEmpty) return null;
    return 'Password needs ${missing.join(', ')}';
  }

  /// Optional field; same pattern as the backend (digits, spaces, +, -, parentheses).
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^[+\d][\d\s()-]{5,29}$').hasMatch(value.trim())) return 'Enter a valid phone number';
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (value) {
      if (value == null || value.isEmpty) return 'Please confirm your password';
      if (value != original()) return 'Passwords do not match';
      return null;
    };
  }
}

class PasswordRule {
  const PasswordRule(this.label, this._test);

  final String label;
  final bool Function(String) _test;

  bool isMetBy(String value) => _test(value);
}
