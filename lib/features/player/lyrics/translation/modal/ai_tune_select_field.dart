import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics/plugins/package/plugin_manifest.dart';
import '../../../../../core/lyrics/plugins/store/plugin_config_values.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import '../../../../../shared/lyrics_plugins/config/plugin_config_commit_mixin.dart';
import '../../../../../shared/lyrics_plugins/config/plugin_config_error_text.dart';
import '../../../../../shared/lyrics_plugins/config/plugin_config_flush_group.dart';
import '../../../../../shared/widgets/selection_picker.dart';
import 'ai_tune_save_target.dart';
import 'translation_ai_badge.dart';
import 'translation_ai_option_label.dart';

final _log = Logger('translation');

/// A model or style of an AI translation plugin in the tune modal: a tonal
/// box with the chosen option's title, its subtitle (two lines at most) and a
/// check mark with a drop arrow; a tap opens a [showSelectionPicker]. A pick
/// is saved at once to where [target] says at that moment (the song, the
/// queue, or the plugin's config without making the translations that failed
/// start over); when the save is refused the old choice comes back and the
/// reason shows under the box.
///
/// [field] is the effective field (with the models the user added) and
/// [stored] the saved values it is read against.
class AiTuneSelectField extends ConsumerStatefulWidget {
  const AiTuneSelectField({
    super.key,
    required this.installId,
    required this.label,
    required this.field,
    required this.stored,
    required this.target,
    this.flushGroup,
  });

  final String installId;

  /// The name of the choice ("Model", "Style"), above the box and as the
  /// title of the list.
  final String label;
  final PluginConfigField field;
  final Map<String, Object?> stored;
  final AiTuneSaveTarget target;
  final PluginConfigFlushGroup? flushGroup;

  @override
  ConsumerState<AiTuneSelectField> createState() => _State();
}

class _State extends ConsumerState<AiTuneSelectField>
    with PluginConfigCommit<AiTuneSelectField> {
  late String? _value = _effective;

  // The failure of the last write to the song or the queue.
  String? _scopedError;

  String? get _effective {
    final value = pluginEffectiveValue(widget.field, widget.stored);
    return value is String && widget.field.options.any((o) => o.value == value)
        ? value
        : null;
  }

  @override
  PluginConfigField get commitField => widget.field;
  @override
  String get commitInstallId => widget.installId;
  // Nothing chosen is an empty string (no saved value).
  @override
  // Only the shared config is committed by the mixin; for the song or the
  // queue it sees what is saved, so it has nothing of its own to write.
  Object? get commitPayload =>
      widget.target.writesConfig ? (_value ?? '') : (_effective ?? '');
  @override
  bool get commitRevertsOnRefusal => true;
  // A pick beside a translation under way must not disturb it.
  @override
  bool get commitForgetsFailures => false;
  @override
  PluginConfigFlushGroup? get commitFlushGroup => widget.flushGroup;

  @override
  void onCommitted(Object? payload) => widget.target.afterConfigSaved();

  @override
  bool get dirty => commitDirty || widget.target.writes.busy;

  @override
  Future<bool> flush() async {
    if (widget.target.writesConfig) return commitFlush();
    await widget.target.writes.idle;
    return mounted && _scopedError == null;
  }

  @override
  void onCommitRefused(Object? lastSaved) =>
      _value = lastSaved is String && lastSaved.isNotEmpty ? lastSaved : null;

  @override
  void didUpdateWidget(AiTuneSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    commitExternal(_effective ?? '');
  }

  @override
  void onExternalValue(Object? payload) {
    // What the pick being written comes back as is not news.
    if (widget.target.writes.busy) return;
    _value = payload is String && payload.isNotEmpty ? payload : null;
  }

  @override
  void initState() {
    super.initState();
    commitStart(commitPayload);
  }

  @override
  void dispose() {
    // The mixin saves a pick still unsaved, or lets one in flight end, without
    // telling the field; the pick was made for all songs, so the default
    // follows it even if that save then fails.
    if (widget.target.writesConfig && commitDirty) {
      // Providers cannot change while the tree is torn down.
      final target = widget.target;
      scheduleMicrotask(target.afterConfigSaved);
    }
    commitTeardown();
    super.dispose();
  }

  Future<void> _open() async {
    final field = widget.field;
    final picked = await showSelectionPicker<String>(
      context,
      title: widget.label,
      items: [
        for (final option in field.options)
          SelectionPickerItem(
            value: option.value,
            name: option.title,
            description: option.subtitle,
            badge: option.custom ? const TranslationAiCustomTag() : null,
          ),
      ],
      selected: _value,
    );
    if (picked == null || picked == _value || !mounted) return;
    setState(() {
      _value = picked;
      _scopedError = null;
    });
    if (widget.target.writesConfig) {
      await commit();
    } else {
      await _writeScoped(picked);
    }
  }

  /// Saves [picked] to the song or the queue, after the writes before it.
  Future<void> _writeScoped(String picked) async {
    final failedText = context.l10n.pluginConfigSaveFailed;
    final group = widget.flushGroup;
    final error = await widget.target.write(
      widget.field.key,
      picked,
      onChange: () => group?.refresh(),
    );
    if (error == null) return;
    _log.warning('saving the AI tune failed: ${error.runtimeType}');
    if (mounted) {
      setState(() {
        _value = _effective;
        _scopedError = failedText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final field = widget.field;
    // What is shown is what a run would use, except right after a pick that
    // is still being saved.
    final label = aiOptionLabel(l10n, field, {
      ...widget.stored,
      field.key: ?_value,
    });
    final chosen = label.chosen;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Text(
              widget.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Semantics(
            container: true,
            button: true,
            label: widget.label,
            child: Material(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _open,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: chosen
                                      ? colors.onSurface
                                      : colors.error,
                                ),
                              ),
                              if (label.subtitle != null)
                                Text(
                                  label.subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (chosen) ...[
                          Icon(AppIcons.check, size: 20, color: colors.primary),
                          const SizedBox(width: 4),
                        ],
                        Icon(AppIcons.expandMore, color: colors.outline),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if ((commitError ?? _scopedError) != null)
            PluginConfigErrorText((commitError ?? _scopedError)!),
        ],
      ),
    );
  }
}
