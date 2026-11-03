import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import 'plugin_config_commit_mixin.dart';
import 'plugin_config_label.dart';
import 'plugin_config_payload_checks.dart';
import 'plugin_config_subtitle.dart';
import 'plugin_config_value_messages.dart';

/// An `input` field of a plugin's form other than a secret: text, multiline,
/// url, number or integer. It saves when the user presses Enter (not in a
/// multiline box) or leaves the field, not on every key; a number is saved
/// as a number. Arrow Up and Down step a number by the field's `step`.
/// Saving an empty text removes the saved value.
///
/// A mistake shows under the box once the field was left, and goes when the
/// text is fixed.
class PluginConfigTextField extends ConsumerStatefulWidget {
  const PluginConfigTextField({
    super.key,
    required this.installId,
    required this.field,
    required this.initialText,
  });

  final String installId;
  final PluginConfigField field;

  /// Saved value, else the manifest's default, as text.
  final String initialText;

  @override
  ConsumerState<PluginConfigTextField> createState() => _State();
}

class _State extends ConsumerState<PluginConfigTextField>
    with PluginConfigCommit<PluginConfigTextField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialText,
  );
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);

  PluginInputFormat get _format =>
      widget.field.inputFormat ?? PluginInputFormat.text;
  bool get _isNumeric =>
      _format == PluginInputFormat.number ||
      _format == PluginInputFormat.integer;
  bool get _isMultiline => _format == PluginInputFormat.multiline;

  @override
  PluginConfigField get commitField => widget.field;
  @override
  String get commitInstallId => widget.installId;

  @override
  Object? get commitPayload {
    final text = _text.text;
    if (!_isNumeric || text.isEmpty) return text;
    return pluginParseFinite(
          text,
          whole: _format == PluginInputFormat.integer,
        ) ??
        text;
  }

  @override
  void initState() {
    super.initState();
    commitStart(commitPayload);
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

  /// Moves the number by [direction] steps, within min and max.
  void _step(int direction) {
    final field = widget.field;
    final whole = _format == PluginInputFormat.integer;
    final typed = pluginParseFinite(_text.text);
    final start =
        typed ?? (field.defaultValue is num ? field.defaultValue as num : 0);
    final step = field.step != null && field.step!.isFinite ? field.step! : 1;
    var next = start + direction * step;
    // Float sums such as 0.1 + 0.2 are rounded away.
    if (next is double && next.isFinite) {
      next = (next * 1e10).round() / 1e10;
    }
    if (!next.isFinite) return;
    // Rounding comes first so a whole number never leaves fractional limits.
    if (whole) next = next.round();
    final min = field.min == null
        ? null
        : (whole ? field.min!.ceil() : field.min!);
    final max = field.max == null
        ? null
        : (whole ? field.max!.floor() : field.max!);
    if (min != null && next < min) next = min;
    if (max != null && next > max) next = max;
    final text = pluginNumberText(next);
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    commitChanged();
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final box = TextField(
      controller: _text,
      focusNode: _focus,
      keyboardType: switch (_format) {
        PluginInputFormat.multiline => TextInputType.multiline,
        PluginInputFormat.url => TextInputType.url,
        PluginInputFormat.integer => const TextInputType.numberWithOptions(
          signed: true,
        ),
        PluginInputFormat.number => const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        _ => TextInputType.text,
      },
      minLines: _isMultiline ? field.rows ?? pluginConfigDefaultRows : 1,
      maxLines: _isMultiline ? field.rows ?? pluginConfigDefaultRows : 1,
      inputFormatters: [
        if (_format == PluginInputFormat.number)
          FilteringTextInputFormatter.allow(RegExp(r'[-+0-9.eE]')),
        if (_format == PluginInputFormat.integer)
          FilteringTextInputFormatter.allow(RegExp(r'[-+0-9]')),
      ],
      onChanged: (_) => commitChanged(),
      onSubmitted: _isMultiline ? null : (_) => commit(),
      decoration: InputDecoration(
        label: PluginConfigLabel(field),
        border: const OutlineInputBorder(),
        errorText: commitError,
        errorMaxLines: 3,
        alignLabelWithHint: _isMultiline,
        // A cleared box means the manifest's default applies.
        hintText:
            field.placeholder ??
            (field.defaultValue is String
                ? field.defaultValue as String
                : null),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PluginConfigSubtitle(field.subtitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _isNumeric
              ? CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                        _step(1),
                    const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                        _step(-1),
                  },
                  child: box,
                )
              : box,
        ),
      ],
    );
  }
}
