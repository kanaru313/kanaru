import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/lyrics/plugins/store/plugin_config_values.dart';
import '../../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../../core/lyrics_translation/translation_ai_tune.dart';
import '../../../../../core/lyrics_translation/translation_ai_tune_provider.dart';
import '../../../../../core/lyrics_translation/translation_providers.dart';
import '../../../../../l10n/l10n.dart';

/// The settings that differ from the version on screen, watched live: the
/// model and style the song's winning choice gives (the plugin's saved ones
/// when the default wins), the shared note, and the note of the song with
/// lyrics hash [hash] (the song the modal opened on). Empty unless [state] is
/// the selected plugin's own finished version with a snapshot.
List<AiTuneChange> watchAiTuneChanges(
  WidgetRef ref,
  LyricsTranslationState state,
  String? hash,
) {
  if (state is! TranslationReady || hash == null) return const [];
  final tune = ref.watch(translationAiTunesProvider)[state.service];
  if (tune == null) return const [];
  final values = ref
      .watch(scopedAiTuneValuesProvider((state.service, hash)))
      .value;
  if (values == null) return const [];
  // Until the song's note is read it is unknown, not empty: comparing early
  // would report a change for a song translated with a note.
  final note = ref.watch(songTranslationInstructionProvider(hash));
  if (!note.hasValue) return const [];
  return aiTuneChangesOf(tune, state, values.stored, note.value);
}

/// The changes as one line: model and style as `before → after` (titles; a
/// value the plugin dropped reads as no longer supported), and "Changed the
/// note" for an instruction. Joined with " · ".
String aiTuneChangesText(
  AppLocalizations l10n,
  TranslationAiTune tune,
  Map<String, Object?> stored,
  List<AiTuneChange> changes,
) {
  String title(AiTuneChange change, Object? value, {bool before = false}) {
    final field = pluginEffectiveField(
      change.key == AiTuneKey.model ? tune.model : tune.style,
      stored,
    );
    if (value == null) return l10n.translationAiNotChosen;
    if (before && change.removedOption) {
      return l10n.translationAiOptionGone('$value');
    }
    return aiOptionTitle(field, value) ?? '$value';
  }

  return [
    for (final change in changes)
      if (change.key == AiTuneKey.instruction)
        l10n.translationAiEditedNote
      else
        '${title(change, change.before, before: true)} → '
            '${title(change, change.after)}',
  ].join(' · ');
}

/// The title of the style a translation was made with, from its snapshot;
/// null without a snapshot or when the plugin no longer offers that style.
String? aiSnapshotStyleTitle(TranslationAiTune tune, String? settingsJson) =>
    aiOptionTitle(tune.style, decodeAiSnapshot(settingsJson)?[aiStyleKey]);
