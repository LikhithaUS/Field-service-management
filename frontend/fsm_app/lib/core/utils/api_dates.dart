/// Converting between API values and Dart dates.
///
/// The backend sends two kinds of values:
/// - **moments** (`createdAt`, `checkIn`): real instants, shown in the device's local time;
/// - **calendar dates** (task `dueDate`, attendance `date`): stored as midnight UTC of the day.
///   Converting those to local time would shift them to the previous day west of UTC,
///   so the UTC calendar date is kept as-is.
class ApiDates {
  ApiDates._();

  static DateTime? parseMoment(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static DateTime? parseDate(Object? value) {
    if (value is! String) return null;
    final utc = DateTime.tryParse(value)?.toUtc();
    return utc == null ? null : DateTime(utc.year, utc.month, utc.day);
  }

  /// A calendar date -> `2026-12-01T00:00:00.000Z` (request bodies).
  static String toIso(DateTime date) => DateTime.utc(date.year, date.month, date.day).toIso8601String();

  /// A calendar date -> `2026-12-01` (query parameters).
  static String toDay(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
