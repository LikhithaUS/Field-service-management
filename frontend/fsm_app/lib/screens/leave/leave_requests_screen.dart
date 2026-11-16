import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/leave_providers.dart';
import '../../widgets/state_views.dart';
import 'leave_screen.dart';
import 'leave_widgets.dart';

/// Admin/manager review queue: everyone's requests, pending ones by default.
class LeaveRequestsScreen extends ConsumerWidget {
  const LeaveRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(leaveRequestsQueryProvider);
    final result = ref.watch(leaveRequestsProvider);
    final notifier = ref.read(leaveRequestsQueryProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Leave requests')),
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
                      onRefresh: () => ref.refresh(leaveRequestsProvider.future),
                      emptyTitle: 'No leave requests',
                      showPerson: true,
                    ),
                  AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(leaveRequestsProvider)),
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
