import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_notification.dart';
import '../../models/paginated.dart';
import '../../providers/notification_providers.dart';
import '../../providers/service_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/state_views.dart';

/// Where tapping a notification goes, or null if it doesn't point at anything.
String? notificationRoute(AppNotification n) {
  final id = n.entityId;
  if (id == null) return null;
  return switch (n.entityType) {
    'task' => AppRoutes.taskDetail(id),
    'leave' => AppRoutes.leaveDetail(id),
    _ => null,
  };
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markingAll = false;

  void _refresh() {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAll = true);
    try {
      await ref.read(notificationServiceProvider).markAllRead();
      _refresh();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      try {
        await ref.read(notificationServiceProvider).markRead(n.id);
        _refresh();
      } on ApiException catch (e) {
        // Not being able to mark it read shouldn't stop the user from opening it.
        if (mounted) showSnack(context, e.message, error: true);
      }
    }
    final route = notificationRoute(n);
    if (route != null && mounted) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(notificationFilterProvider);
    final result = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton.icon(
            onPressed: unread == 0 || _markingAll ? null : _markAllRead,
            icon: const Icon(Icons.done_all),
            label: const Text('Mark all read'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(unread == 0 ? 'Unread only' : 'Unread only ($unread)'),
                      selected: filter.unreadOnly,
                      onSelected: ref.read(notificationFilterProvider.notifier).setUnreadOnly,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: switch (result) {
                  AsyncValue(:final value?) => _List(page: value, unreadOnly: filter.unreadOnly, onOpen: _open),
                  AsyncValue(:final error?) => ErrorView(error: error, onRetry: _refresh),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.page, required this.unreadOnly, required this.onOpen});

  final Paginated<AppNotification> page;
  final bool unreadOnly;
  final ValueChanged<AppNotification> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.items.isEmpty) {
      return EmptyView(
        icon: Icons.notifications_none,
        title: unreadOnly ? "You're all caught up" : 'No notifications yet',
        message: unreadOnly ? null : 'Task assignments, comments and leave updates will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(unreadCountProvider);
        return ref.refresh(notificationsProvider.future);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: page.items.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == page.items.length) {
            return PaginationBar(page: page, onPageChanged: ref.read(notificationFilterProvider.notifier).setPage);
          }
          final n = page.items[index];
          return _NotificationTile(notification: n, onTap: () => onOpen(n));
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.type) {
        NotificationType.taskAssigned => Icons.assignment_ind_outlined,
        NotificationType.taskCompleted => Icons.task_alt,
        NotificationType.taskComment => Icons.chat_bubble_outline,
        NotificationType.leaveRequested => Icons.event_note_outlined,
        NotificationType.leaveDecision => Icons.beach_access_outlined,
        NotificationType.general => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = !notification.isRead;

    return Card(
      margin: EdgeInsets.zero,
      color: unread ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: unread ? scheme.primary : scheme.surfaceContainerHighest,
          foregroundColor: unread ? scheme.onPrimary : scheme.onSurfaceVariant,
          child: Icon(_icon, size: 20),
        ),
        title: Text(
          notification.title,
          style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500),
        ),
        subtitle: Text(
          [if (notification.message.isNotEmpty) notification.message, Formatters.relative(notification.createdAt)].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: unread
            ? Semantics(
                label: 'Unread',
                child: Container(width: 10, height: 10, decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
              )
            : null,
      ),
    );
  }
}
