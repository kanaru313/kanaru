import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../../core/lyrics_translation/translation_ai_tune.dart';
import '../../../../../core/lyrics_translation/translation_ai_tune_provider.dart';
import '../../../../../core/lyrics_translation/translation_providers.dart';

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

/// The title of the style a translation was made with, from its snapshot;
/// null without a snapshot or when the plugin no longer offers that style.
String? aiSnapshotStyleTitle(TranslationAiTune tune, String? settingsJson) =>
    aiOptionTitle(tune.style, decodeAiSnapshot(settingsJson)?[aiStyleKey]);
