import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_providers.dart';
import '../../routes/app_router.dart';

/// Home screen. Each tile is a module from the plan; tiles with a route are live,
/// the rest light up as modules are built. Tiles differ by role.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _modules = <_Module>[
    _Module('Employees', Icons.badge_outlined, {UserRole.admin, UserRole.manager}, route: AppRoutes.employees),
    _Module('Departments', Icons.apartment_outlined, {UserRole.admin}, route: AppRoutes.departments),
    _Module('Tasks', Icons.task_alt_outlined, {UserRole.admin, UserRole.manager, UserRole.employee},
        route: AppRoutes.tasks),
    _Module('Attendance', Icons.schedule_outlined, {UserRole.admin, UserRole.manager, UserRole.employee},
        route: AppRoutes.attendance),
    _Module('Leave', Icons.beach_access_outlined, {UserRole.admin, UserRole.manager, UserRole.employee},
        route: AppRoutes.leave),
    _Module('Notifications', Icons.notifications_outlined, {UserRole.admin, UserRole.manager, UserRole.employee},
        route: AppRoutes.notifications),
    _Module('Announcements', Icons.campaign_outlined, {UserRole.admin, UserRole.manager, UserRole.employee}),
    _Module('Reports', Icons.insights_outlined, {UserRole.admin, UserRole.manager}),
  ];

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink(); // router is redirecting to login

    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final modules = _modules.where((m) => m.roles.contains(user.role)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ServiceHub'),
        actions: [
          const _NotificationBell(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive grid: 2 columns on phones, up to 4 on wide web/desktop windows.
          final columns = (constraints.maxWidth / 260).floor().clamp(2, 4);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${user.firstName}',
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          avatar: Icon(Icons.verified_user_outlined, size: 18, color: scheme.primary),
                          label: Text(user.role.label),
                        ),
                        Text(user.email, style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // Fixed tile height (not an aspect ratio) so tiles never get too
                      // short for their content on narrow phones.
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 128,
                      ),
                      children: [for (final m in modules) _ModuleCard(module: m)],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Module {
  const _Module(this.title, this.icon, this.roles, {this.route});
  final String title;
  final IconData icon;
  final Set<UserRole> roles;
  final String? route; // null = not built yet
}

/// Opens a screen and refreshes the bell's unread count on the way back, since tasks
/// and leave actions on other screens may have created or read notifications.
Future<void> _openAndRefresh(BuildContext context, WidgetRef ref, String route) async {
  await context.push(route);
  ref.invalidate(unreadCountProvider);
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider).value ?? 0;
    return IconButton(
      tooltip: count == 0 ? 'Notifications' : 'Notifications ($count unread)',
      onPressed: () => _openAndRefresh(context, ref, AppRoutes.notifications),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _ModuleCard extends ConsumerWidget {
  const _ModuleCard({required this.module});
  final _Module module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final live = module.route != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: live ? () => _openAndRefresh(context, ref, module.route!) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(module.icon, color: live ? scheme.primary : scheme.outline, size: 28),
              const Spacer(),
              Text(
                module.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                live ? 'Open' : 'Coming soon',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: live ? scheme.primary : scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
