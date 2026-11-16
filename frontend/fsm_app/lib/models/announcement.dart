import 'package:flutter/material.dart' show IconData, Icons;

import '../core/utils/api_dates.dart';
import 'person_ref.dart';
import 'user.dart';

enum AnnouncementCategory {
  general('General', Icons.campaign_outlined),
  holiday('Holiday', Icons.celebration_outlined),
  maintenance('Maintenance', Icons.build_outlined),
  meeting('Meeting', Icons.groups_outlined),
  important('Important', Icons.priority_high);

  const AnnouncementCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  String get apiValue => name;

  static AnnouncementCategory fromString(String? value) =>
      AnnouncementCategory.values.firstWhere((c) => c.name == value, orElse: () => AnnouncementCategory.general);
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    this.category = AnnouncementCategory.general,
    this.pinned = false,
    this.author,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String message;
  final AnnouncementCategory category;
  final bool pinned;
  final PersonRef? author;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Edited after posting (more than a minute later, to ignore the create itself).
  bool get wasEdited =>
      createdAt != null && updatedAt != null && updatedAt!.difference(createdAt!) > const Duration(minutes: 1);

  /// Same rule as the backend: admins manage all, managers only their own.
  bool canBeManagedBy(User user) => user.isAdmin || (user.isManager && author?.id == user.id);

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: (json['id'] ?? json['_id']) as String,
        title: json['title'] as String,
        message: json['message'] as String? ?? '',
        category: AnnouncementCategory.fromString(json['category'] as String?),
        pinned: json['pinned'] as bool? ?? false,
        author: PersonRef.fromJson(json['author']),
        createdAt: ApiDates.parseMoment(json['createdAt']),
        updatedAt: ApiDates.parseMoment(json['updatedAt']),
      );
}
