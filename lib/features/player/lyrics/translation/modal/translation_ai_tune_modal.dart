import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../../../../core/lyrics/plugins/store/plugin_config_values.dart';
import '../../../../../core/lyrics_translation/translation_ai_tune_provider.dart';
import '../../../../../core/lyrics_translation/translation_service.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/lyrics_plugins/config/plugin_config_flush_group.dart';
import '../../../../../shared/lyrics_plugins/config/plugin_config_initial_value.dart';
import '../../../../../shared/widgets/layered_modal/layered_modal_route.dart';
import 'ai_tune_select_field.dart';
import 'translation_modal_navigation.dart';
import 'translation_song_instruction_field.dart';

/// Opens the AI tuning child modal for [service] over the translation modal
/// that holds [context]: the model, the style and a note for the song with
/// lyrics hash [hash] (the hash of the song when the modal opened). Returns
/// true when the modal asks for a retranslation; closing it only saves.
Future<bool?> openAiTuneModal(
  BuildContext context, {
  required TranslationServiceId service,
  required String hash,
}) => showLayeredModal<bool>(
  context,
  semanticLabel: context.l10n.translationAiTuneRow,
  builder: (_) => TranslationAiTuneModal(
    service: service,
    hash: hash,
    // The button closes the parent too, which the child's own context cannot.
    onOpenPluginSettings: () => openTranslationPlugin(context, service),
  ),
);

/// Content of the AI tuning modal: only the three standard fields of an
/// `ai-translate` plugin, saved as they are left. They go to the plugin's own
/// config (shared with Settings) without making failed translations start
/// over; the note goes to the song.
class TranslationAiTuneModal extends ConsumerStatefulWidget {
  const TranslationAiTuneModal({
    super.key,
    required this.service,
    required this.hash,
    required this.onOpenPluginSettings,
  });

  final TranslationServiceId service;
  final String hash;
  final VoidCallback onOpenPluginSettings;

  @override
  ConsumerState<TranslationAiTuneModal> createState() => _State();
}

class _State extends ConsumerState<TranslationAiTuneModal> {
  final _group = PluginConfigFlushGroup();

  @override
  void dispose() {
    _group.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final id = widget.service.value;
    final values = ref.watch(aiTuneValuesProvider(widget.service));
    final record = ref.watch(
      lyricsPluginRecordsProvider.select((records) {
        for (final r in records) {
          if (r.installId == id) return r;
        }
        return null;
      }),
    );
    final data = values.value;

    return LayeredModalBody(
      header: LayeredModalTopBar(title: l10n.translationAiTuneRow),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.translationAiTuneDone),
          ),
        ),
      ),
      children: [
        if (values.isLoading)
          const SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (data == null || record == null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.pluginConfigLoadFailed),
          )
        else ...[
          _model(data, record.updatedAt),
          AiTuneSelectField(
            key: pluginConfigEditorKey(
              id,
              record.updatedAt,
              data.tune.style.key,
              data.stored,
            ),
            installId: id,
            label: l10n.translationAiStyle,
            field: pluginEffectiveField(data.tune.style, data.stored),
            stored: data.stored,
            flushGroup: _group,
          ),
          TranslationSongInstructionField(
            key: ValueKey(widget.hash),
            hash: widget.hash,
            field: data.tune.instruction,
            flushGroup: _group,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Text(
              l10n.translationAiTuneHint(record.name),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _model(AiTuneStored data, int updatedAt) {
    final l10n = context.l10n;
    final field = pluginEffectiveField(data.tune.model, data.stored);
    // A list of only the user's models, still empty: nothing can run yet, and
    // adding a model is done in the plugin's settings.
    if (field.custom && field.options.isEmpty) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.translationAiModel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.translationAiNoModels, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: widget.onOpenPluginSettings,
                child: Text(l10n.translationAiOpenPluginSettings),
              ),
            ),
          ],
        ),
      );
    }
    return AiTuneSelectField(
      key: pluginConfigEditorKey(
        widget.service.value,
        updatedAt,
        field.key,
        data.stored,
      ),
      installId: widget.service.value,
      label: l10n.translationAiModel,
      field: field,
      stored: data.stored,
      flushGroup: _group,
    );
  }
}
