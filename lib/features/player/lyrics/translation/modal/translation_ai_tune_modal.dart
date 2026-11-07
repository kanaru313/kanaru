import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics/plugins/lyrics_plugin_record.dart';
import '../../../../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../../../../core/lyrics/plugins/store/plugin_config_values.dart';
import '../../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../../core/lyrics_translation/translation_ai_tune_provider.dart';
import '../../../../../core/lyrics_translation/translation_scope.dart';
import '../../../../../core/lyrics_translation/translation_service.dart';
import '../../../../../core/player/player_service.dart';
import '../../../../../core/settings/settings_provider.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/lyrics_plugins/config/plugin_config_flush_group.dart';
import '../../../../../shared/lyrics_plugins/config/plugin_config_initial_value.dart';
import '../../../../../shared/widgets/layered_modal/layered_modal_route.dart';
import 'ai_tune_save_target.dart';
import 'ai_tune_scoped_writes.dart';
import 'ai_tune_select_field.dart';
import 'translation_ai_tune_changes.dart';
import 'translation_ai_tune_scope.dart';
import 'translation_modal_navigation.dart';
import 'translation_scope_header.dart';
import 'translation_service_pick.dart';
import 'translation_song_instruction_field.dart';

/// Opens the AI tuning child modal for [service] over the translation modal
/// that holds [context]: the model, the style and a note for the song with
/// lyrics hash [hash] (the hash of the song when the modal opened). Returns
/// true when the modal asks for a retranslation; closing it only saves.
/// [appLang] is the translation modal's app language, to read the version on
/// screen.
Future<bool?> openAiTuneModal(
  BuildContext context, {
  required TranslationServiceId service,
  required String hash,
  required String appLang,
}) => showLayeredModal<bool>(
  context,
  semanticLabel: context.l10n.translationAiTuneRow,
  builder: (_) => TranslationAiTuneModal(
    service: service,
    hash: hash,
    appLang: appLang,
    // The button closes the parent too, which the child's own context cannot.
    onOpenPluginSettings: () => openTranslationPlugin(context, service),
  ),
);

/// Content of the AI tuning modal: only the three standard fields of an
/// `ai-translate` plugin, saved as they are left. The scope segments above say
/// where a model or style goes: this song's own choice, the queue's, or the
/// plugin's shared config (also made the default service), without making
/// failed translations start over. "This song" is chosen on every open. The
/// note always goes to the song.
class TranslationAiTuneModal extends ConsumerStatefulWidget {
  const TranslationAiTuneModal({
    super.key,
    required this.service,
    required this.hash,
    required this.appLang,
    required this.onOpenPluginSettings,
  });

  final TranslationServiceId service;
  final String hash;
  final String appLang;
  final VoidCallback onOpenPluginSettings;

  @override
  ConsumerState<TranslationAiTuneModal> createState() => _State();
}

class _State extends ConsumerState<TranslationAiTuneModal> {
  final _group = PluginConfigFlushGroup();
  final _writes = AiTuneScopedWrites();

  // The scope segment; "this song" on every open (a locked one falls back to
  // all songs when built).
  TranslationScope _scope = TranslationScope.song;

  // A retranslation was asked for: the buttons stay locked until the modal
  // closes or the save fails. [_popped] makes sure it closes once.
  bool _busy = false;
  bool _popped = false;
  // The last Retranslate could not save everything in time.
  bool _failed = false;

  /// Saves what the editors hold, then closes asking the parent to
  /// retranslate. A refused, failed or slow save keeps the modal open.
  Future<void> _retranslate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    var ok = false;
    try {
      ok = await _group.flushAll().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
    } catch (_) {
      // Counts as not saved.
    }
    if (!mounted) return;
    // Only this modal's own route may close: Escape, the stack closing on a
    // track change or a picker on top would make a plain pop take another one.
    final route = ModalRoute.of(context);
    final current = route != null && route.isCurrent;
    if (!ok || !current) {
      setState(() {
        _busy = false;
        _failed = !ok;
      });
      return;
    }
    if (_popped) return;
    _popped = true;
    Navigator.of(context).pop(true);
  }

  Widget _footer(AppLocalizations l10n, bool changed) {
    return ValueListenableBuilder<bool>(
      valueListenable: _group.anyDirty,
      builder: (context, dirty, _) {
        final later = _busy || changed || dirty;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.pluginConfigSaveFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: later
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Text(l10n.translationAiTuneLater),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => unawaited(_retranslate()),
                            child: _busy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(l10n.lyricsTranslationRetranslate),
                          ),
                        ],
                      )
                    : FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.translationAiTuneDone),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

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
    final show = ref.watch(settingsProvider.select((s) => s.translation.show));
    final queueEmpty = ref.watch(
      playerServiceProvider.select((s) => s.queue.isEmpty),
    );
    final locked = aiTuneScopeLocks(l10n, show: show, queueEmpty: queueEmpty);
    final scope = locked.containsKey(_scope) ? TranslationScope.all : _scope;
    // The shared config is what the "all songs" segment edits; the others
    // show what this song runs with now.
    final values = scope == TranslationScope.all
        ? ref.watch(aiTuneValuesProvider(widget.service))
        : ref.watch(scopedAiTuneValuesProvider((widget.service, widget.hash)));
    final caption = allScopeCaption(ref);
    final record = ref.watch(
      lyricsPluginRecordsProvider.select((records) {
        for (final r in records) {
          if (r.installId == id) return r;
        }
        return null;
      }),
    );
    final data = values.value;
    final state = ref.watch(lyricsTranslationProvider(widget.appLang));

    return LayeredModalBody(
      header: LayeredModalTopBar(title: l10n.translationAiTuneRow),
      footer: _footer(
        l10n,
        watchAiTuneChanges(ref, state, widget.hash).isNotEmpty,
      ),
      children: [
        TranslationScopeHeader(
          scopes: const [
            TranslationScope.song,
            TranslationScope.queue,
            TranslationScope.all,
          ],
          selected: scope,
          locked: locked,
          precedence: caption.precedence,
          customCount: caption.songs,
          queueHasChoice: caption.queue,
          onChanged: (s) => setState(() {
            _scope = s;
            _writes.written.clear();
          }),
        ),
        // The editors are frozen while a retranslation is being asked for, so
        // no picker opens over the modal that is about to close.
        IgnorePointer(
          ignoring: _busy,
          child: ExcludeFocus(
            excluding: _busy,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _editors(l10n, theme, values, data, record, scope),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _editors(
    AppLocalizations l10n,
    ThemeData theme,
    AsyncValue<AiTuneStored> values,
    AiTuneStored? data,
    LyricsPluginRecord? record,
    TranslationScope scope,
  ) {
    final id = widget.service.value;
    final target = aiTuneTargetFor(
      selected: scope,
      locked: const {},
      container: ProviderScope.containerOf(context),
      service: widget.service,
      hash: widget.hash,
      writes: _writes,
    );
    return [
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
        _model(data, record.updatedAt, target),
        AiTuneSelectField(
          key: ValueKey((
            pluginConfigEditorKey(
              id,
              record.updatedAt,
              data.tune.style.key,
              data.stored,
            ),
            scope,
          )),
          installId: id,
          label: l10n.translationAiStyle,
          field: pluginEffectiveField(data.tune.style, data.stored),
          stored: data.stored,
          target: target,
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
    ];
  }

  Widget _model(AiTuneStored data, int updatedAt, AiTuneSaveTarget target) {
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
      key: ValueKey((
        pluginConfigEditorKey(
          widget.service.value,
          updatedAt,
          field.key,
          data.stored,
        ),
        target.scope,
      )),
      installId: widget.service.value,
      label: l10n.translationAiModel,
      field: field,
      stored: data.stored,
      target: target,
      flushGroup: _group,
    );
  }
}
