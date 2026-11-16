import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/validators.dart';

/// A password input with show/hide, plus Copy / Cut / Paste / Select all.
///
/// Flutter (and the browser, for web password inputs) disables copy and cut on hidden
/// text by default. Users asked to copy their own password, so this field provides
/// those actions itself: in the right-click / long-press menu and with Ctrl/Cmd+C and +X.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.errorText,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final String? errorText;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;
  final _focus = FocusNode();

  TextEditingController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _focus.addListener(_useFlutterMenuOnWeb);
  }

  @override
  void dispose() {
    if (kIsWeb && _focus.hasFocus) BrowserContextMenu.enableContextMenu();
    _focus.dispose();
    super.dispose();
  }

  // The browser's own menu greys out Copy for password inputs, so show ours while focused.
  void _useFlutterMenuOnWeb() {
    if (_focus.hasFocus) {
      BrowserContextMenu.disableContextMenu();
    } else {
      BrowserContextMenu.enableContextMenu();
    }
  }

  /// The selected text, or the whole password if nothing is selected.
  TextRange get _target {
    final sel = _c.selection;
    if (sel.isValid && !sel.isCollapsed) return sel;
    return TextRange(start: 0, end: _c.text.length);
  }

  Future<void> _copy({bool cut = false}) async {
    final range = _target;
    if (range.isCollapsed) return;
    await Clipboard.setData(ClipboardData(text: range.textInside(_c.text)));
    if (cut) _c.value = _c.value.replaced(range, '');
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || text.isEmpty) return;
    final v = _c.value;
    final range = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    _c.value = v.replaced(range, text);
  }

  Widget _menu(BuildContext context, EditableTextState state) {
    void run(VoidCallback action) {
      state.hideToolbar();
      action();
    }

    final hasText = _c.text.isNotEmpty;
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: [
        if (hasText) ContextMenuButtonItem(type: ContextMenuButtonType.cut, onPressed: () => run(() => _copy(cut: true))),
        if (hasText) ContextMenuButtonItem(type: ContextMenuButtonType.copy, onPressed: () => run(_copy)),
        ContextMenuButtonItem(type: ContextMenuButtonType.paste, onPressed: () => run(_paste)),
        if (hasText)
          ContextMenuButtonItem(
            type: ContextMenuButtonType.selectAll,
            onPressed: () => state.selectAll(SelectionChangedCause.toolbar),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): _copy,
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true): _copy,
        const SingleActivator(LogicalKeyboardKey.keyX, control: true): () => _copy(cut: true),
        const SingleActivator(LogicalKeyboardKey.keyX, meta: true): () => _copy(cut: true),
      },
      child: TextFormField(
        controller: _c,
        focusNode: _focus,
        obscureText: _obscure,
        validator: widget.validator,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        autofillHints: widget.autofillHints,
        enableInteractiveSelection: true,
        contextMenuBuilder: _menu,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.lock_outline),
          errorText: widget.errorText,
          errorMaxLines: 3,
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
    );
  }
}

/// Live checklist of the password requirements, ticked off as the user types.
class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final value = controller.text;
        return Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your password needs:', style: small?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              for (final rule in Validators.passwordRules)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        rule.isMetBy(value) ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: rule.isMetBy(value) ? Colors.green.shade600 : scheme.outline,
                        semanticLabel: rule.isMetBy(value) ? 'Done' : 'Not yet',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rule.label[0].toUpperCase() + rule.label.substring(1),
                          style: small?.copyWith(color: rule.isMetBy(value) ? scheme.onSurface : scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
