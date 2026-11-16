import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/announcement.dart';
import '../../providers/announcement_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/badges.dart';
import '../../widgets/state_views.dart';

class AnnouncementDetailsScreen extends ConsumerWidget {
  const AnnouncementDetailsScreen({super.key, required this.announcementId});

  final String announcementId;

  Future<void> _delete(BuildContext context, WidgetRef ref, Announcement a) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this announcement?',
      message: '"${a.title}" will be removed for everyone, along with its notifications.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(announcementServiceProvider).delete(a.id);
      refreshAnnouncements(ref);
      if (!context.mounted) return;
      showSnack(context, 'Announcement deleted');
      context.go(AppRoutes.announcements);
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(authControllerProvider).value;
    final result = ref.watch(announcementDetailProvider(announcementId));
    final a = result.value;
    final canManage = viewer != null && a != null && a.canBeManagedBy(viewer);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement'),
        actions: [
          if (canManage) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(AppRoutes.announcementEdit(announcementId)),
            ),
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref, a)),
          ],
        ],
      ),
      body: switch (result) {
        AsyncValue(:final value?) => _Body(announcement: value),
        AsyncValue(:final error?) =>
          ErrorView(error: error, onRetry: () => ref.invalidate(announcementDetailProvider(announcementId))),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final a = announcement;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(avatar: Icon(a.category.icon, size: 18), label: Text(a.category.label)),
                  if (a.pinned) const Chip(avatar: Icon(Icons.push_pin, size: 18), label: Text('Pinned')),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(a.title, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                children: [
                  InitialsAvatar(initials: a.author?.initials ?? '?', radius: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      [
                        a.author?.name ?? 'Unknown',
                        Formatters.dateTime(a.createdAt),
                        if (a.wasEdited) 'edited',
                      ].join(' · '),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              SelectableText(a.message, style: textTheme.bodyLarge?.copyWith(height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}
