import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugins_provider.dart';
import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import '../../core/lyrics_translation/translation_jobs.dart';
import '../../l10n/l10n.dart';
import '../../shared/lyrics_plugins/config/plugin_config_save.dart';
import '../../shared/lyrics_plugins/config/plugin_config_commit_mixin.dart';
import '../../shared/lyrics_plugins/config/plugin_config_label.dart';
import '../../shared/lyrics_plugins/config/plugin_config_subtitle.dart';
import 'plugin_config_add_model_dialog.dart';

final _log = Logger('lyrics_sources');

/// A `select` field with one value: a dropdown of the manifest's options,
/// each with its subtitle. It saves at once; when the save is refused the old
/// choice comes back and the reason shows under the box.
///
/// A `custom` field (the [field] is the effective one, with the user's own
/// choices after the plugin's) marks the user's choices, lets them be
/// removed, and ends the list with "Add model…". Adding and removing write
/// through the plugin controller; the form then rebuilds this box from the
/// saved values.
class PluginConfigSelectField extends ConsumerStatefulWidget {
  const PluginConfigSelectField({
    super.key,
    required this.installId,
    required this.field,
    required this.initialValue,
  });

  final String installId;
  final PluginConfigField field;

  /// The saved or default option value; null shows nothing chosen.
  final String? initialValue;

  @override
  ConsumerState<PluginConfigSelectField> createState() => _SelectState();
}

class _SelectState extends ConsumerState<PluginConfigSelectField>
    with PluginConfigCommit<PluginConfigSelectField> {
  late String? _value =
      widget.field.options.any((o) => o.value == widget.initialValue)
      ? widget.initialValue
      : null;

  @override
  PluginConfigField get commitField => widget.field;
  @override
  String get commitInstallId => widget.installId;
  // Nothing chosen is an empty string (no saved value).
  @override
  Object? get commitPayload => _value ?? '';
  @override
  bool get commitRevertsOnRefusal => true;

  @override
  void onCommitRefused(Object? lastSaved) =>
      _value = lastSaved is String && lastSaved.isNotEmpty ? lastSaved : null;

  String? _known(Object? value) =>
      value is String && widget.field.options.any((o) => o.value == value)
      ? value
      : null;

  @override
  void didUpdateWidget(PluginConfigSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    commitExternal(_known(widget.initialValue) ?? '');
  }

  @override
  void onExternalValue(Object? payload) => _value = _known(payload);

  @override
  void initState() {
    super.initState();
    commitStart(commitPayload);
  }

  @override
  void dispose() {
    commitTeardown();
    super.dispose();
  }

  void _choose(String? next) {
    if (next == null || next == _value) return;
    setState(() => _value = next);
    commit();
  }

  // The "Add model…" entry of a `custom` list; no option has this value.
  static const _addValue = '\u0000add';

  Future<void> _addModel() async {
    final entry = await showPluginConfigAddModelDialog(context);
    if (entry == null || !mounted) return;
    final options = widget.field.options;
    if (!options.any((o) => o.value == entry.name) &&
        options.length >= pluginConfigMaxItems) {
      setState(
        () => commitError = context.l10n.pluginConfigTooManyItems(
          pluginConfigMaxItems,
        ),
      );
      return;
    }
    await _change(
      (plugins) => plugins.addCustomModel(
        widget.installId,
        entry.name,
        subtitle: entry.note,
      ),
    );
  }

  Future<void> _removeModel(String value) =>
      _change((plugins) => plugins.removeCustomModel(widget.installId, value));

  // Runs a change of the user's own models. A saved change may fix what
  // failed, like any other saved value; a refusal or an error shows under the
  // box. The form rebuilds this box from the saved values.
  Future<void> _change(
    Future<PluginConfigWrite> Function(LyricsPluginsController) run,
  ) async {
    final l10n = context.l10n;
    final plugins = ref.read(lyricsPluginsControllerProvider);
    final jobs = ref.read(translationJobsProvider.notifier);
    String? message = l10n.pluginConfigSaveFailed;
    try {
      if (plugins != null) {
        final write = await run(plugins);
        message = pluginConfigWriteMessage(l10n, write);
        if (write == PluginConfigWrite.written) {
          forgetTranslationFailures(jobs, widget.installId);
        }
      }
    } on Object catch (error, stackTrace) {
      _log.warning('Changing the models failed', error, stackTrace);
    }
    if (!mounted) return;
    setState(() => commitError = message);
  }

  Widget _optionTile(ThemeData theme, PluginConfigOption option) {
    final l10n = context.l10n;
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(option.title),
        if (option.subtitle != null)
          Text(
            option.subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    if (!option.custom) return text;
    return Row(
      children: [
        Expanded(child: text),
        const SizedBox(width: 8),
        _CustomTag(l10n.pluginConfigCustomModelTag),
        IconButton(
          tooltip: l10n.pluginConfigRemoveCustomModel,
          icon: const Icon(Icons.delete_outline, size: 20),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            // Close the open list, then remove.
            Navigator.of(context).pop();
            _removeModel(option.value);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final custom = widget.field.custom;
    // A list of only the user's models, still empty: nothing can run.
    final noModel = custom && widget.field.options.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InputDecorator(
            decoration: InputDecoration(
              label: PluginConfigLabel(widget.field),
              border: const OutlineInputBorder(),
              errorText:
                  commitError ?? (noModel ? l10n.pluginConfigNoModel : null),
              errorMaxLines: 3,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _value,
                isExpanded: true,
                isDense: true,
                // The box shows the title alone; the list adds the subtitle.
                selectedItemBuilder: (_) => [
                  for (final option in widget.field.options)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        children: [
                          Flexible(child: Text(option.title)),
                          if (option.custom) ...[
                            const SizedBox(width: 8),
                            _CustomTag(l10n.pluginConfigCustomModelTag),
                          ],
                        ],
                      ),
                    ),
                  if (custom) const SizedBox.shrink(),
                ],
                items: [
                  for (final option in widget.field.options)
                    DropdownMenuItem(
                      value: option.value,
                      child: _optionTile(theme, option),
                    ),
                  if (custom)
                    DropdownMenuItem(
                      value: _addValue,
                      child: Row(
                        children: [
                          const Icon(Icons.add, size: 20),
                          const SizedBox(width: 12),
                          Text(l10n.pluginConfigAddModel),
                        ],
                      ),
                    ),
                ],
                onChanged: (next) =>
                    next == _addValue ? _addModel() : _choose(next),
              ),
            ),
          ),
        ),
        PluginConfigSubtitle(widget.field.subtitle),
      ],
    );
  }
}

/// The small "Custom" label on a choice the user added.
class _CustomTag extends StatelessWidget {
  const _CustomTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
