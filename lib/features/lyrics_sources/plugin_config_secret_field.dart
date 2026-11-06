import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/lyrics_plugins/config/plugin_config_commit_mixin.dart';
import '../../shared/lyrics_plugins/config/plugin_config_label.dart';
import '../../shared/lyrics_plugins/config/plugin_config_subtitle.dart';
import 'plugin_config_save.dart';

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
  late final TextEditingController _text = TextEditingController()
    ..addListener(_onTextChanged);
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);
  late bool _hasSecret = widget.hasSavedSecret;
  late bool _hasText = _text.text.isNotEmpty;
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
  void didUpdateWidget(PluginConfigSecretField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasSavedSecret != widget.hasSavedSecret) {
      _hasSecret = widget.hasSavedSecret;
    }
  }

  void _onTextChanged() {
    final hasText = _text.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void onCommitted(Object? payload) {
    setState(() {
      _hasSecret = true;
      _revealed = false;
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
      if (message == null) {
        _hasSecret = false;
        _revealed = false;
      }
      commitError = message;
    });
    if (message == null) commitChanged();
  }

  Widget? _suffixIcon(AppLocalizations l10n) {
    final showClear = _hasSecret && !_hasText;
    final showReveal = _hasText;
    if (!showClear && !showReveal) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showClear)
          IconButton(
            tooltip: l10n.pluginSecretClear,
            icon: const Icon(AppIcons.closeRounded),
            onPressed: _clearSecret,
          ),
        if (showReveal)
          IconButton(
            tooltip: _revealed ? l10n.pluginSecretHide : l10n.pluginSecretShow,
            icon: Icon(
              _revealed ? AppIcons.visibilityOff : AppIcons.visibility,
            ),
            onPressed: () => setState(() => _revealed = !_revealed),
          ),
      ],
    );
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
              floatingLabelBehavior: _hasSecret
                  ? FloatingLabelBehavior.always
                  : FloatingLabelBehavior.auto,
              hintText: _hasSecret ? '••••••••' : widget.field.placeholder,
              suffixIcon: _suffixIcon(l10n),
            ),
          ),
        ),
        PluginConfigSubtitle(widget.field.subtitle),
      ],
    );
  }
}
