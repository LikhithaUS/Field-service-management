import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/attendance.dart';
import '../../widgets/badges.dart';

/// Day counts and total hours for the filtered range.
class AttendanceSummaryBar extends StatelessWidget {
  const AttendanceSummaryBar({super.key, required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Stat(label: 'Present', value: '${summary.present}', icon: Icons.check_circle_outline),
        _Stat(label: 'Late', value: '${summary.late}', icon: Icons.schedule),
        _Stat(label: 'Half day', value: '${summary.halfDay}', icon: Icons.timelapse),
        _Stat(label: 'Hours', value: Formatters.duration(Duration(minutes: summary.totalMinutes)), icon: Icons.timer_outlined),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Text('$label ', style: TextStyle(color: scheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// One day's record. With [showPerson] the person's name is the title (team report).
class AttendanceRecordTile extends StatelessWidget {
  const AttendanceRecordTile({super.key, required this.record, this.showPerson = false, this.showDate = true});

  final AttendanceRecord record;
  final bool showPerson;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final missed = record.missedCheckOut();

    final String outPart;
    if (record.checkOut != null) {
      outPart = 'Out ${Formatters.time(record.checkOut)} · ${Formatters.duration(record.worked())}';
    } else if (missed) {
      outPart = 'Missed check-out';
    } else {
      outPart = 'Working…';
    }

    final title = showPerson ? (record.user?.name ?? 'Unknown') : Formatters.dayDate(record.date);
    final lines = [
      if (showPerson && showDate) Formatters.dayDate(record.date),
      'In ${Formatters.time(record.checkIn)} · $outPart',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: showPerson
            ? InitialsAvatar(initials: record.user?.initials ?? '?')
            : CircleAvatar(
                backgroundColor: scheme.surfaceContainerHighest,
                foregroundColor: scheme.onSurface,
                child: Text('${record.date.day}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          lines.join('\n'),
          style: missed ? TextStyle(color: scheme.error) : null,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: AttendanceStatusBadge(status: record.status),
      ),
    );
  }
}
