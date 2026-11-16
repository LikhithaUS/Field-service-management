/// Small display helpers (kept dependency-free; swap for `intl` if localisation is needed).
class Formatters {
  Formatters._();

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// 06 Nov 2026
  static String date(DateTime? value) {
    if (value == null) return '—';
    return '${value.day.toString().padLeft(2, '0')} ${_months[value.month - 1]} ${value.year}';
  }

  /// 06 Nov 2026, 14:05
  static String dateTime(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '${date(local)}, $time';
  }
}
