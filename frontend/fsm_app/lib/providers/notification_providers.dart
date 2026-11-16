import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../models/paginated.dart';
import 'service_providers.dart';

/// The number on the bell. Refreshed when returning to the dashboard and after reading.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(notificationServiceProvider).unreadCount();
});

/// (page, unreadOnly) for the notifications screen.
final notificationFilterProvider = NotifierProvider.autoDispose<NotificationFilterController, ({int page, bool unreadOnly})>(
  NotificationFilterController.new,
);

class NotificationFilterController extends Notifier<({int page, bool unreadOnly})> {
  @override
  ({int page, bool unreadOnly}) build() => (page: 1, unreadOnly: false);

  void setUnreadOnly(bool value) => state = (page: 1, unreadOnly: value);
  void setPage(int page) => state = (page: page, unreadOnly: state.unreadOnly);
}

final notificationsProvider = FutureProvider.autoDispose<Paginated<AppNotification>>((ref) {
  final filter = ref.watch(notificationFilterProvider);
  return ref.watch(notificationServiceProvider).list(page: filter.page, unreadOnly: filter.unreadOnly);
});
