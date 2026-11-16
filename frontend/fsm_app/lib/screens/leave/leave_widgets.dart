import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/leave.dart';
import '../../routes/app_router.dart';
import '../../widgets/badges.dart';

String leaveRange(LeaveRequest leave) => leave.isSingleDay
    ? Formatters.date(leave.startDate)
    : '${Formatters.date(leave.startDate)} – ${Formatters.date(leave.endDate)}';

String leaveDays(int days) => '$days working day${days == 1 ? '' : 's'}';

/// One request in a list. With [showPerson] the requester's name is the title (review queue).
class LeaveTile extends StatelessWidget {
  const LeaveTile({super.key, required this.leave, this.showPerson = false});

  final LeaveRequest leave;
  final bool showPerson;

  @override
  Widget build(BuildContext context) {
    final title = showPerson ? (leave.user?.name ?? 'Unknown') : leave.leaveType.label;
    final details = [
      if (showPerson) leave.leaveType.label,
      leaveRange(leave),
      leaveDays(leave.days),
    ];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: showPerson
            ? InitialsAvatar(initials: leave.user?.initials ?? '?')
            : const CircleAvatar(child: Icon(Icons.beach_access_outlined)),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(details.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: LeaveStatusBadge(status: leave.status),
        onTap: () => context.push(AppRoutes.leaveDetail(leave.id)),
      ),
    );
  }
}

/// Status + type dropdowns shared by "My leave" and the review queue.
class LeaveFilters extends StatelessWidget {
  const LeaveFilters({
    super.key,
    required this.status,
    required this.leaveType,
    required this.onStatus,
    required this.onType,
  });

  final LeaveStatus? status;
  final LeaveType? leaveType;
  final ValueChanged<LeaveStatus?> onStatus;
  final ValueChanged<LeaveType?> onType;

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) =>
        InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<LeaveStatus?>(
              key: ValueKey('status:$status'),
              initialValue: status,
              isExpanded: true,
              isDense: true,
              decoration: deco('Status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All statuses')),
                for (final s in LeaveStatus.values) DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: onStatus,
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<LeaveType?>(
              key: ValueKey('type:$leaveType'),
              initialValue: leaveType,
              isExpanded: true,
              isDense: true,
              decoration: deco('Type'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All types')),
                for (final t in LeaveType.values) DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: onType,
            ),
          ),
        ],
      ),
    );
  }
}
