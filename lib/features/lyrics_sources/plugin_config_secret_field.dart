import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'plugin_config_commit_mixin.dart';
import 'plugin_config_label.dart';
import 'plugin_config_save.dart';
import 'plugin_config_subtitle.dart';

/// A secret `input` field: hidden, with a reveal toggle. It saves when the
/// user presses Enter or leaves the field.
///
/// A secret is never read back: the box starts empty and says whether a
/// value is saved. Leaving it empty changes nothing; the clear button removes
/// the saved value.
class PluginConfigSecretField extends ConsumerStatefulWidget {
  const PluginConfigSecretField({
    super.key,
    required this.installId,
    required this.field,
    required this.hasSavedSecret,
    required this.usingFallback,
  });

  final String installId;
  final PluginConfigField field;
  final bool hasSavedSecret;

  /// The secret store is a file or memory: the note says so.
  final bool usingFallback;

  @override
  ConsumerState<PluginConfigSecretField> createState() => _State();
}

class _State extends ConsumerState<PluginConfigSecretField>
    with PluginConfigCommit<PluginConfigSecretField> {
  final TextEditingController _text = TextEditingController();
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);
  late bool _hasSecret = widget.hasSavedSecret;
  bool _revealed = false;

  @override
  PluginConfigField get commitField => widget.field;
  @override
  String get commitInstallId => widget.installId;
  @override
  Object? get commitPayload => _text.text;
  @override
  bool get commitSkipsEmpty => true;
  @override
  bool get commitHasHiddenValue => _hasSecret;

  @override
  void initState() {
    super.initState();
    commitStart('');
  }

  @override
  void onCommitted(Object? payload) {
    setState(() {
      _hasSecret = true;
      // Text typed during the save stays.
      if (_text.text == payload) _text.clear();
    });
  }

  @override
  void dispose() {
    commitTeardown();
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus) commitOnBlur();
  }

  Future<void> _clearSecret() async {
    final result = await savePluginConfigValue(
      context,
      ref,
      widget.installId,
      widget.field.key,
      '',
    );
    if (!mounted) return;
    final message = result.message;
    setState(() {
      if (message == null) _hasSecret = false;
      commitError = message;
    });
    if (message == null) commitChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final helper = widget.usingFallback
        ? l10n.pluginSecretFallbackNote
        : (_hasSecret ? l10n.pluginSecretSaved : l10n.pluginSecretNote);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PluginConfigSubtitle(widget.field.subtitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _text,
            focusNode: _focus,
            obscureText: !_revealed,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => commitChanged(),
            onSubmitted: (_) => commit(),
            decoration: InputDecoration(
              label: PluginConfigLabel(widget.field),
              border: const OutlineInputBorder(),
              errorText: commitError,
              errorMaxLines: 3,
              helperText: helper,
              helperMaxLines: 3,
              helperStyle: widget.usingFallback
                  ? TextStyle(color: theme.colorScheme.tertiary)
                  : null,
              hintText: _hasSecret ? '••••••••' : widget.field.placeholder,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasSecret)
                    IconButton(
                      tooltip: l10n.pluginSecretClear,
                      icon: const Icon(AppIcons.closeRounded),
                      onPressed: _clearSecret,
                    ),
                  IconButton(
                    tooltip: _revealed
                        ? l10n.pluginSecretHide
                        : l10n.pluginSecretShow,
                    icon: Icon(
                      _revealed ? AppIcons.visibilityOff : AppIcons.visibility,
                    ),
                    onPressed: () => setState(() => _revealed = !_revealed),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
