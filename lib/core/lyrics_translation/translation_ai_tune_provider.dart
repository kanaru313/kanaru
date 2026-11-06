import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lyrics/plugins/lyrics_sources_provider.dart';
import '../lyrics/plugins/plugin_config_values_provider.dart';
import '../lyrics/plugins/store/plugin_config_values.dart';
import 'translation_ai_tune.dart';
import 'translation_service.dart';

/// The tune of each live `ai-translate` plugin that declares the three
/// standard fields, by service. A `translate` plugin, a removed one, and a
/// record without a standard field (saved by an older version) are not in it.
/// Read from the records already in memory, so it is always in step with them.
final translationAiTunesProvider =
    Provider<Map<TranslationServiceId, TranslationAiTune>>((ref) {
      final tunes = <TranslationServiceId, TranslationAiTune>{};
      for (final record in ref.watch(lyricsPluginRecordsProvider)) {
        final id = TranslationServiceId.tryParse(record.installId);
        final tune = aiTuneOf(record.kind, record.config);
        if (!record.isRemoved && id != null && tune != null) tunes[id] = tune;
      }
      return tunes;
    });

/// What the tune modal reads of one plugin's saved values: only the keys the
/// tune shows, never the rest (an API key is not held by the player UI).
@immutable
class AiTuneStored {
  const AiTuneStored(this.tune, this.stored);

  final TranslationAiTune tune;

  /// The saved `model`, `style`, `customInstruction` and the user's own
  /// models (`model.custom`); a key with no saved value is absent.
  final Map<String, Object?> stored;

  /// What a run reads now (see [aiTuneValues]).
  ({Object? model, Object? style, String instruction}) get values =>
      aiTuneValues(tune, stored);

  @override
  bool operator ==(Object other) =>
      other is AiTuneStored &&
      other.tune == tune &&
      mapEquals(other.stored, stored);

  @override
  int get hashCode => Object.hash(tune, stored.length);
}

/// The saved values the tune of [service] shows, live. Loading until the
/// stored values are read; an error when they cannot be; and an error state
/// too when the service has no tune (it is not an `ai-translate` plugin).
final aiTuneValuesProvider = Provider.autoDispose
    .family<AsyncValue<AiTuneStored>, TranslationServiceId>((ref, service) {
      final tune = ref.watch(translationAiTunesProvider)[service];
      if (tune == null) {
        return AsyncError('no tune for $service', StackTrace.current);
      }
      final stored = ref.watch(pluginStoredConfigProvider(service.value));
      return stored.when(
        data: (map) => AsyncData(
          AiTuneStored(tune, {
            for (final key in const [aiModelKey, aiStyleKey, aiInstructionKey])
              if (map[key] != null) key: map[key],
            pluginCustomChoicesKey(aiModelKey):
                ?map[pluginCustomChoicesKey(aiModelKey)],
          }),
        ),
        error: AsyncError.new,
        loading: () => const AsyncLoading(),
      );
    });
