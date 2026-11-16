/// Small display helpers (kept dependency-free; swap for `intl` if localisation is needed).
class Formatters {
  Formatters._();

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// 06 Nov 2026
  static String date(DateTime? value) {
    if (value == null) return '—';
    return '${value.day.toString().padLeft(2, '0')} ${_months[value.month - 1]} ${value.year}';
  }

  /// 14:05 (local time)
  static String time(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// 526 min -> "8h 46m", 45 min -> "45m"
  static String duration(Duration value) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60);
    return h == 0 ? '${m}m' : '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  /// Mon, 16 Nov 2026
  static String dayDate(DateTime? value) {
    if (value == null) return '—';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[value.weekday - 1]}, ${date(value)}';
  }

  /// 06 Nov 2026, 14:05
  static String dateTime(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '${date(local)}, $time';
  }
}
