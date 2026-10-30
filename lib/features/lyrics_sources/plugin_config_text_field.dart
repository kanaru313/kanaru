import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import '../../core/lyrics/plugins/store/plugin_config_values.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'plugin_config_save.dart';

/// An `input` field of a plugin's form: text, number (number keyboard, checked
/// before saving) or secret (hidden, with a reveal toggle). It saves when the
/// user presses Enter or leaves the field, not on every key.
///
/// A secret is never read back: the field starts empty and says whether a
/// value is saved. Saving an empty text removes the saved value.
class PluginConfigTextField extends ConsumerStatefulWidget {
  const PluginConfigTextField({
    super.key,
    required this.installId,
    required this.field,
    required this.initialText,
    required this.hasSavedSecret,
    required this.usingFallback,
  });

  final String installId;
  final PluginConfigField field;

  /// Saved value, else the manifest's default; empty for a secret.
  final String initialText;
  final bool hasSavedSecret;

  /// The secret store is a file or memory: the note says so.
  final bool usingFallback;

  @override
  ConsumerState<PluginConfigTextField> createState() => _State();
}

class _State extends ConsumerState<PluginConfigTextField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialText,
  );
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);
  late String _saved = widget.initialText;
  late bool _hasSecret = widget.hasSavedSecret;
  bool _revealed = false;
  String? _error;

  /// A save is under way: Enter and then leaving the field must not save
  /// the same text twice. Text committed meanwhile waits in [_queued].
  bool _saving = false;
  bool _queued = false;
  String? _inFlight;

  /// The text whose save was refused; it is not tried again at teardown.
  String? _refused;

  // Kept for the save at teardown, when the context can no longer be asked.
  LyricsPluginsController? _plugins;
  AppLocalizations? _l10n;

  bool get _isSecret => widget.field.inputFormat == PluginInputFormat.secret;
  bool get _isNumber => widget.field.inputFormat == PluginInputFormat.number;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _plugins = ref.read(lyricsPluginsControllerProvider);
    _l10n = context.l10n;
  }

  /// Whether the box holds text nobody is saving yet and that may be saved.
  bool _worthSaving(String text) =>
      text != _saved &&
      text != _inFlight &&
      text != _refused &&
      !(_isSecret && text.isEmpty) &&
      !(_isNumber && text.isNotEmpty && !pluginValueFits(widget.field, text));

  @override
  void dispose() {
    // Leaving the page with the field still focused does not call the focus
    // listener; the last edit is saved here, best effort.
    final text = _text.text;
    final plugins = _plugins;
    final l10n = _l10n;
    if (_worthSaving(text) && plugins != null && l10n != null) {
      unawaited(
        savePluginConfigValueWith(
          controller: plugins,
          // The page is going away: a snackbar has no Scaffold left to show
          // in, so a refusal is only logged.
          messenger: null,
          l10n: l10n,
          installId: widget.installId,
          key: widget.field.key,
          value: text,
        ),
      );
    }
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus) _commit();
  }

  /// A secret box is empty unless the user typed a new value; leaving it
  /// empty changes nothing (use the clear button to remove the saved value).
  Future<void> _commit() async {
    if (_saving) {
      _queued = true;
      return;
    }
    final text = _text.text;
    if (text == _saved || (_isSecret && text.isEmpty)) return;
    if (_isNumber && text.isNotEmpty && !pluginValueFits(widget.field, text)) {
      setState(() => _error = context.l10n.pluginConfigNumberInvalid);
      return;
    }
    setState(() => _error = null);
    _saving = true;
    _inFlight = text;
    final bool ok;
    try {
      ok = await savePluginConfigValue(
        context,
        ref,
        widget.installId,
        widget.field.key,
        text,
      );
    } finally {
      _saving = false;
      _inFlight = null;
    }
    if (!mounted) return;
    _refused = ok ? null : text;
    if (ok) {
      _saved = _isSecret ? '' : text;
      if (_isSecret) {
        setState(() {
          _hasSecret = true;
          // Text typed during the save stays.
          if (_text.text == text) _text.clear();
        });
      }
    }
    if (_queued) {
      _queued = false;
      unawaited(_commit());
    }
  }

  Future<void> _clearSecret() async {
    final ok = await savePluginConfigValue(
      context,
      ref,
      widget.installId,
      widget.field.key,
      '',
    );
    if (ok && mounted) setState(() => _hasSecret = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final helper = _isSecret
        ? (widget.usingFallback
              ? l10n.pluginSecretFallbackNote
              : (_hasSecret ? l10n.pluginSecretSaved : l10n.pluginSecretNote))
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _text,
        focusNode: _focus,
        obscureText: _isSecret && !_revealed,
        autocorrect: !_isSecret,
        enableSuggestions: !_isSecret,
        keyboardType: _isNumber
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        inputFormatters: [
          if (_isNumber)
            FilteringTextInputFormatter.allow(RegExp(r'[-+0-9.eE]')),
        ],
        onSubmitted: (_) => _commit(),
        decoration: InputDecoration(
          labelText: widget.field.title,
          border: const OutlineInputBorder(),
          errorText: _error,
          helperText: helper,
          helperMaxLines: 3,
          helperStyle: widget.usingFallback && _isSecret
              ? TextStyle(color: theme.colorScheme.tertiary)
              : null,
          // A cleared box means the manifest's default applies.
          hintText: _isSecret
              ? (_hasSecret ? '••••••••' : null)
              : (widget.field.defaultValue is String
                    ? widget.field.defaultValue as String
                    : null),
          suffixIcon: !_isSecret
              ? null
              : Row(
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
                        _revealed
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(() => _revealed = !_revealed),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
