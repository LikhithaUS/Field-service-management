import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/announcement.dart';
import '../../models/paginated.dart';
import '../../providers/announcement_providers.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_router.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/state_views.dart';

class AnnouncementListScreen extends ConsumerStatefulWidget {
  const AnnouncementListScreen({super.key});

  @override
  ConsumerState<AnnouncementListScreen> createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends ConsumerState<AnnouncementListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(announcementFilterProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(authControllerProvider).value;
    if (viewer == null) return const SizedBox.shrink();
    final filter = ref.watch(announcementFilterProvider);
    final result = ref.watch(announcementsProvider);
    final notifier = ref.read(announcementFilterProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: viewer.isEmployee
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.announcementNew),
              icon: const Icon(Icons.campaign),
              label: const Text('New announcement'),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(hintText: 'Search announcements…', prefixIcon: Icon(Icons.search)),
                ),
              ),
              // Category chips scroll sideways on narrow phones.
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  children: [
                    ChoiceChip(label: const Text('All'), selected: filter.category == null, onSelected: (_) => notifier.setCategory(null)),
                    for (final c in AnnouncementCategory.values) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        avatar: Icon(c.icon, size: 18),
                        label: Text(c.label),
                        selected: filter.category == c,
                        onSelected: (selected) => notifier.setCategory(selected ? c : null),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: switch (result) {
                  AsyncValue(:final value?) => _List(page: value, filtered: filter.category != null || filter.search.isNotEmpty),
                  AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(announcementsProvider)),
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
  const _List({required this.page, required this.filtered});

  final Paginated<Announcement> page;
  final bool filtered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.items.isEmpty) {
      return EmptyView(
        icon: Icons.campaign_outlined,
        title: filtered ? 'No announcements match' : 'No announcements yet',
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.refresh(announcementsProvider.future),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: page.items.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == page.items.length) {
            return PaginationBar(page: page, onPageChanged: ref.read(announcementFilterProvider.notifier).setPage);
          }
          return AnnouncementCard(announcement: page.items[index]);
        },
      ),
    );
  }
}

/// Used by the list and by the dashboard's "latest announcement" card.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.announcement, this.compact = false});

  final Announcement announcement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final important = announcement.category == AnnouncementCategory.important;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.announcementDetail(announcement.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: important ? scheme.errorContainer : scheme.secondaryContainer,
                foregroundColor: important ? scheme.onErrorContainer : scheme.onSecondaryContainer,
                child: Icon(announcement.category.icon, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (announcement.pinned) ...[
                          Icon(Icons.push_pin, size: 16, color: scheme.primary, semanticLabel: 'Pinned'),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            announcement.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      announcement.message,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${announcement.category.label} · ${announcement.author?.name ?? 'Unknown'} · ${Formatters.relative(announcement.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
