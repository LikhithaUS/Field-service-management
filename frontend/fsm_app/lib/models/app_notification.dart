import '../core/utils/api_dates.dart';

enum NotificationType {
  taskAssigned('task_assigned'),
  taskCompleted('task_completed'),
  taskComment('task_comment'),
  leaveRequested('leave_requested'),
  leaveDecision('leave_decision'),
  general('general');

  const NotificationType(this.apiValue);

  final String apiValue;

  static NotificationType fromString(String? value) =>
      NotificationType.values.firstWhere((t) => t.apiValue == value, orElse: () => NotificationType.general);
}

/// Named AppNotification because Flutter already has a `Notification` class (widgets).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.message = '',
    this.type = NotificationType.general,
    this.entityType,
    this.entityId,
    this.isRead = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final NotificationType type;

  /// What the notification points at ('task' or 'leave'), so tapping it can open that screen.
  final String? entityType;
  final String? entityId;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification markedRead() => AppNotification(
        id: id,
        title: title,
        message: message,
        type: type,
        entityType: entityType,
        entityId: entityId,
        isRead: true,
        createdAt: createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: (json['id'] ?? json['_id']) as String,
        title: json['title'] as String,
        message: json['message'] as String? ?? '',
        type: NotificationType.fromString(json['type'] as String?),
        entityType: json['entityType'] as String?,
        entityId: json['entityId'] as String?,
        isRead: json['isRead'] as bool? ?? false,
        createdAt: ApiDates.parseMoment(json['createdAt']),
      );
}
