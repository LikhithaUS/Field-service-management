import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/announcement.dart';
import '../models/paginated.dart';
import 'service_providers.dart';

typedef AnnouncementFilter = ({AnnouncementCategory? category, String search, int page});

final announcementFilterProvider = NotifierProvider.autoDispose<AnnouncementFilterController, AnnouncementFilter>(
  AnnouncementFilterController.new,
);

class AnnouncementFilterController extends Notifier<AnnouncementFilter> {
  @override
  AnnouncementFilter build() => (category: null, search: '', page: 1);

  void setCategory(AnnouncementCategory? category) => state = (category: category, search: state.search, page: 1);
  void setSearch(String search) => state = (category: state.category, search: search.trim(), page: 1);
  void setPage(int page) => state = (category: state.category, search: state.search, page: page);
}

final announcementsProvider = FutureProvider.autoDispose<Paginated<Announcement>>((ref) {
  final f = ref.watch(announcementFilterProvider);
  return ref.watch(announcementServiceProvider).list(category: f.category, search: f.search, page: f.page);
});

/// The top post (pinned first, then newest) for the dashboard card; null if there are none.
final latestAnnouncementProvider = FutureProvider.autoDispose<Announcement?>((ref) async {
  final page = await ref.watch(announcementServiceProvider).list(limit: 1);
  return page.items.isEmpty ? null : page.items.first;
});

final announcementDetailProvider = FutureProvider.autoDispose.family<Announcement, String>((ref, id) {
  return ref.watch(announcementServiceProvider).get(id);
});

void refreshAnnouncements(WidgetRef ref, {String? id}) {
  ref.invalidate(announcementsProvider);
  ref.invalidate(latestAnnouncementProvider);
  if (id != null) ref.invalidate(announcementDetailProvider(id));
}
