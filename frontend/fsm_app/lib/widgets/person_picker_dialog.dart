import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/exceptions/api_exception.dart';
import '../models/employee.dart';
import '../models/employee_query.dart';
import '../models/paginated.dart';
import '../models/person_ref.dart';
import '../models/user.dart';
import '../providers/service_providers.dart';
import 'badges.dart';

/// Searchable list of active employees with a login account, plus a "me" shortcut.
/// Returns a [PersonRef] whose id is the *user* id, because tasks and attendance
/// reference login accounts, not employee records. Staff only (uses the employees API).
class PersonPickerDialog extends ConsumerStatefulWidget {
  const PersonPickerDialog({super.key, required this.viewer, required this.title, required this.selfLabel});

  final User viewer;
  final String title;
  final String selfLabel;

  @override
  ConsumerState<PersonPickerDialog> createState() => _PersonPickerDialogState();
}

class _PersonPickerDialogState extends ConsumerState<PersonPickerDialog> {
  late Future<Paginated<Employee>> _results = _load('');
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<Paginated<Employee>> _load(String search) => ref
      .read(employeeServiceProvider)
      .list(EmployeeQuery(search: search.trim(), status: EmployeeStatus.active, limit: 20));

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _results = _load(value)));
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.viewer;

    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(hintText: 'Search employees…', prefixIcon: Icon(Icons.search)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(widget.selfLabel),
              subtitle: Text(me.name),
              onTap: () => Navigator.pop(
                context,
                PersonRef(id: me.id, name: me.name, email: me.email, role: me.role, employeeId: me.employeeId),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<Paginated<Employee>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    final e = snapshot.error;
                    return Center(child: Text(e is ApiException ? e.message : 'Could not load employees'));
                  }
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  // Employees without a linked account can't sign in, so they can't be assigned.
                  final people = snapshot.data!.items.where((e) => e.userId != null && e.userId != me.id).toList();
                  if (people.isEmpty) return const Center(child: Text('No matching employees'));

                  return ListView.builder(
                    itemCount: people.length,
                    itemBuilder: (context, i) {
                      final e = people[i];
                      return ListTile(
                        leading: InitialsAvatar(initials: e.initials),
                        title: Text(e.name),
                        subtitle: Text(
                          [e.employeeId, if (e.designation.isNotEmpty) e.designation].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          PersonRef(id: e.userId!, name: e.name, email: e.email, role: e.role, employeeId: e.employeeId),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}
