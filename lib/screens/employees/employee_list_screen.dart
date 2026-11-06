import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/employee.dart';
import '../../models/employee_query.dart';
import '../../models/paginated.dart';
import '../../models/user.dart';
import '../../providers/department_providers.dart';
import '../../providers/employee_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/badges.dart';
import '../../widgets/state_views.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  late final TextEditingController _search = TextEditingController(text: ref.read(employeeQueryProvider).search);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  // Wait until the user pauses typing before hitting the API.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(employeeQueryProvider.notifier).setSearch(value);
    });
  }

  void _clearFilters() {
    _search.clear();
    ref.read(employeeQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(employeeQueryProvider);
    final result = ref.watch(employeeListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.employeeNew),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add employee'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search name, email, ID, phone…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              _onSearchChanged('');
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ),
              _Filters(query: query, onClear: _clearFilters),
              // Thin progress bar while a new page/filter loads over the previous results.
              SizedBox(height: 3, child: result.isLoading && result.hasValue ? const LinearProgressIndicator() : null),
              Expanded(
                child: switch (result) {
                  AsyncValue(:final value?) => _EmployeeList(page: value, hasFilters: query.hasFilters, onClear: _clearFilters),
                  AsyncValue(:final error?) => ErrorView(error: error, onRetry: () => ref.invalidate(employeeListProvider)),
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

class _Filters extends ConsumerWidget {
  const _Filters({required this.query, required this.onClear});

  final EmployeeQuery query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(employeeQueryProvider.notifier);
    final departments = ref.watch(departmentsProvider).value ?? const [];

    // `key` forces each dropdown to rebuild when its filter is cleared externally.
    Widget dropdown<T>({
      required String label,
      required T? value,
      required List<DropdownMenuItem<T?>> items,
      required ValueChanged<T?> onChanged,
    }) {
      return SizedBox(
        width: 190,
        child: DropdownButtonFormField<T?>(
          key: ValueKey('$label:$value'),
          initialValue: value,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          items: items,
          onChanged: onChanged,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          dropdown<String>(
            label: 'Department',
            value: query.departmentId,
            items: [
              const DropdownMenuItem(value: null, child: Text('All departments')),
              const DropdownMenuItem(value: EmployeeQuery.noDepartment, child: Text('No department')),
              for (final d in departments) DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: notifier.setDepartment,
          ),
          dropdown<UserRole>(
            label: 'Role',
            value: query.role,
            items: [
              const DropdownMenuItem(value: null, child: Text('All roles')),
              for (final r in UserRole.values) DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: notifier.setRole,
          ),
          dropdown<EmployeeStatus>(
            label: 'Status',
            value: query.status,
            items: [
              const DropdownMenuItem(value: null, child: Text('All statuses')),
              for (final s in EmployeeStatus.values) DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: notifier.setStatus,
          ),
          if (query.hasFilters)
            TextButton.icon(onPressed: onClear, icon: const Icon(Icons.filter_alt_off_outlined), label: const Text('Clear filters')),
        ],
      ),
    );
  }
}

class _EmployeeList extends ConsumerWidget {
  const _EmployeeList({required this.page, required this.hasFilters, required this.onClear});

  final Paginated<Employee> page;
  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.items.isEmpty) {
      return hasFilters
          ? EmptyView(
              icon: Icons.search_off,
              title: 'No employees match your filters',
              action: OutlinedButton(onPressed: onClear, child: const Text('Clear filters')),
            )
          : const EmptyView(
              icon: Icons.groups_outlined,
              title: 'No employees yet',
              message: 'Tap "Add employee" to create the first one.',
            );
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(employeeListProvider.future),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), // room for the FAB
        itemCount: page.items.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == page.items.length) return _PaginationBar(page: page);
          return _EmployeeTile(employee: page.items[index]);
        },
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      employee.employeeId,
      if (employee.designation.isNotEmpty) employee.designation,
      employee.department?.name ?? 'No department',
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: InitialsAvatar(initials: employee.initials),
        title: Text(employee.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Wrap(
          direction: Axis.vertical,
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [RoleBadge(role: employee.role), StatusBadge(status: employee.status)],
        ),
        onTap: () => context.push(AppRoutes.employeeDetail(employee.id)),
      ),
    );
  }
}

class _PaginationBar extends ConsumerWidget {
  const _PaginationBar({required this.page});

  final Paginated<Employee> page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(employeeQueryProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing ${page.from}–${page.to} of ${page.total}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: page.hasPrevious ? () => notifier.setPage(page.page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('${page.page} / ${page.totalPages}'),
          IconButton(
            tooltip: 'Next page',
            onPressed: page.hasNext ? () => notifier.setPage(page.page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
