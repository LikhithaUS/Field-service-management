import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/utils/validators.dart';
import '../../models/announcement.dart';
import '../../providers/announcement_providers.dart';
import '../../providers/service_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/state_views.dart';

/// Post (announcementId == null) or edit an announcement. Admins and managers only.
class AnnouncementFormScreen extends ConsumerWidget {
  const AnnouncementFormScreen({super.key, this.announcementId});

  final String? announcementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEdit = announcementId != null;
    final Widget body;
    if (!isEdit) {
      body = const _Form();
    } else {
      final result = ref.watch(announcementDetailProvider(announcementId!));
      body = switch (result) {
        AsyncValue(:final value?) => _Form(initial: value),
        AsyncValue(:final error?) =>
          ErrorView(error: error, onRetry: () => ref.invalidate(announcementDetailProvider(announcementId!))),
        _ => const Center(child: CircularProgressIndicator()),
      };
    }
    return Scaffold(appBar: AppBar(title: Text(isEdit ? 'Edit announcement' : 'New announcement')), body: body);
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({this.initial});

  final Announcement? initial;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _message = TextEditingController(text: widget.initial?.message);
  late AnnouncementCategory _category = widget.initial?.category ?? AnnouncementCategory.general;
  late bool _pinned = widget.initial?.pinned ?? false;
  bool _saving = false;
  ApiException? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'title': _title.text.trim(),
      'message': _message.text.trim(),
      'category': _category.apiValue,
      'pinned': _pinned,
    };
    setState(() => _saving = true);
    final service = ref.read(announcementServiceProvider);
    try {
      final saved = _isEdit ? await service.update(widget.initial!.id, data) : await service.create(data);
      refreshAnnouncements(ref, id: saved.id);
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Changes saved' : 'Announcement posted. Everyone has been notified.');
      context.go(AppRoutes.announcementDetail(saved.id));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null && _error!.fieldErrors.isEmpty) ...[ErrorBanner(message: _error!.message), gap],
                TextFormField(
                  controller: _title,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => Validators.required(v, field: 'Title'),
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    prefixIcon: const Icon(Icons.title),
                    errorText: _error?.fieldErrors['title'],
                  ),
                ),
                gap,
                DropdownButtonFormField<AnnouncementCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.label_outline)),
                  items: [
                    for (final c in AnnouncementCategory.values)
                      DropdownMenuItem(
                        value: c,
                        child: Row(children: [Icon(c.icon, size: 18), const SizedBox(width: 8), Text(c.label)]),
                      ),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                gap,
                TextFormField(
                  controller: _message,
                  minLines: 5,
                  maxLines: 12,
                  maxLength: 3000,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => Validators.required(v, field: 'Message'),
                  decoration: InputDecoration(
                    labelText: 'Message *',
                    alignLabelWithHint: true,
                    errorText: _error?.fieldErrors['message'],
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _pinned,
                  onChanged: (v) => setState(() => _pinned = v),
                  title: const Text('Pin to top'),
                  subtitle: const Text('Pinned announcements stay above newer ones'),
                ),
                if (!_isEdit)
                  Text(
                    'Everyone will get a notification when you post.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 24),
                LoadingButton(label: _isEdit ? 'Save changes' : 'Post announcement', loading: _saving, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
