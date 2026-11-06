/// Small display helpers (kept dependency-free; swap for `intl` if localisation is needed).
class Formatters {
  Formatters._();

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// 06 Nov 2026
  static String date(DateTime? value) {
    if (value == null) return '—';
    return '${value.day.toString().padLeft(2, '0')} ${_months[value.month - 1]} ${value.year}';
  }
}
