import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/leave.dart';
import '../../models/leave_query.dart';
import '../../models/paginated.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/state_views.dart';
import 'leave_widgets.dart';

/// Everyone's own leave requests, with "Apply for leave". Staff also get "Requests" to review.
class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(authControllerProvider).value;
    if (viewer == null) return const SizedBox.shrink();
    final query = ref.watch(myLeaveQueryProvider);
    final result = ref.watch(myLeavesProvider);
    final notifier = ref.read(myLeaveQueryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My leave'),
        actions: [
          if (!viewer.isEmployee)
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.leaveRequests),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Requests'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.leaveApply),
        icon: const Icon(Icons.add),
        label: const Text('Apply for leave'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              LeaveFilters(status: query.status, leaveType: query.leaveType, onStatus: notifier.setStatus, onType: notifier.setType),
              SizedBox(height: 3, child: result.isLoading && result.hasValue ? const LinearProgressIndicator() : null),
              Expanded(
                child: switch (result) {
                  AsyncValue(:final value?) => LeaveList(
                      page: value,
                      query: query,
                      onPage: notifier.setPage,
                      onRefresh: () => ref.refresh(myLeavesProvider.future),
                      emptyTitle: 'No leave requests yet',
                      emptyMessage: 'Tap "Apply for leave" to request time off.',
                    ),
                  AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(myLeavesProvider)),
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

class LeaveList extends StatelessWidget {
  const LeaveList({
    super.key,
    required this.page,
    required this.query,
    required this.onPage,
    required this.onRefresh,
    required this.emptyTitle,
    this.emptyMessage,
    this.showPerson = false,
  });

  final Paginated<LeaveRequest> page;
  final LeaveQuery query;
  final ValueChanged<int> onPage;
  final Future<Object?> Function() onRefresh;
  final String emptyTitle;
  final String? emptyMessage;
  final bool showPerson;

  @override
  Widget build(BuildContext context) {
    if (page.items.isEmpty) {
      final filtered = query.status != null || query.leaveType != null;
      return EmptyView(
        icon: Icons.beach_access_outlined,
        title: filtered ? 'No requests match your filters' : emptyTitle,
        message: filtered ? null : emptyMessage,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), // room for the FAB
        itemCount: page.items.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == page.items.length) return PaginationBar(page: page, onPageChanged: onPage);
          return LeaveTile(leave: page.items[index], showPerson: showPerson);
        },
      ),
    );
  }
}
