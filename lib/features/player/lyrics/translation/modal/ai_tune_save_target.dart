import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/library_startup.dart';
import '../../../../../core/database/lyric_translation_queries.dart';
import '../../../../../core/lyrics_translation/queue_translation_choice.dart';
import '../../../../../core/lyrics_translation/translation_ai_tune.dart';
import '../../../../../core/lyrics_translation/translation_ai_tune_provider.dart';
import '../../../../../core/lyrics_translation/translation_clock.dart';
import '../../../../../core/lyrics_translation/translation_scope.dart';
import '../../../../../core/lyrics_translation/translation_service.dart';
import '../../../../../core/settings/settings_provider.dart';
import 'ai_tune_scoped_writes.dart';

/// Where a pick of the tune modal goes, chosen by the scope segment at the
/// moment of the write:
///
/// * [TranslationScope.song]: the song's own choice (its service, the model
///   and the style, and a new stamp); the row is created when missing.
/// * [TranslationScope.queue]: the queue's choice, the same way.
/// * [TranslationScope.all]: the plugin's shared config (written by the field
///   itself); [afterConfigSaved] then makes the plugin the default service
///   with a new stamp, so the shared settings win over older narrower choices.
///
/// Holds a [ProviderContainer], not a widget `ref`: a write may finish after
/// the modal that started it is gone. A write to the song or the queue reads
/// the model and style in effect when it runs (after the writes before it,
/// see [writes]), so one pick writes both keys.
class AiTuneSaveTarget {
  const AiTuneSaveTarget({
    required this.scope,
    required this.container,
    required this.service,
    required this.hash,
    required this.writes,
  });

  final TranslationScope scope;
  final ProviderContainer container;

  /// The plugin the modal was opened for.
  final TranslationServiceId service;

  /// The lyrics hash of the song the modal was opened on.
  final String hash;

  /// The queue of the modal's song and queue writes.
  final AiTuneScopedWrites writes;

  /// Whether a pick goes to the plugin's config (the field's own commit).
  bool get writesConfig => scope == TranslationScope.all;

  /// Queues the save of [value] for the field [key] (`model` or `style`) to
  /// the song or the queue. Completes with the error, or null when saved. Not
  /// for [writesConfig].
  Future<Object?> write(
    String key,
    String value, {
    void Function()? onChange,
  }) => writes.enqueue(() => _save(key, value), onChange: onChange);

  Future<void> _save(String key, String value) async {
    final data = container
        .read(scopedAiTuneValuesProvider((service, hash)))
        .value;
    if (data == null) throw StateError('the tune values are not known');
    final stored = aiTuneCurrent(data.tune, data.stored);
    writes.written.removeWhere((k, v) => stored[k] == v);
    final tune = {...stored, ...writes.written, key: value};
    final chosenAt = container.read(translationClockProvider)();
    switch (scope) {
      case TranslationScope.song:
        final db = container.read(libraryDatabaseProvider);
        if (db == null) throw StateError('no library database');
        await db.setSongTranslationTune(
          hash,
          service: service.value,
          tune: tune,
          chosenAt: chosenAt,
        );
        writes.written[key] = value;
      case TranslationScope.queue:
        container
            .read(queueTranslationChoiceProvider.notifier)
            .set(service, tune: tune, chosenAt: chosenAt);
        writes.written[key] = value;
      case TranslationScope.all:
        throw StateError('the shared config is saved by the field');
    }
  }

  /// After the shared config took a pick: the plugin becomes the default
  /// service, stamped now.
  void afterConfigSaved() {
    final settings = container.read(settingsProvider.notifier);
    final prefs = container.read(settingsProvider).translation;
    settings.setTranslation(
      prefs.copyWith(
        service: service,
        allChosenAt: container.read(translationClockProvider)(),
      ),
    );
  }
}

/// The model and style [stored] gives a run, as strings.
Map<String, String> aiTuneCurrent(
  TranslationAiTune tune,
  Map<String, Object?> stored,
) {
  final values = aiTuneValues(tune, stored);
  return {
    if (values.model is String) aiModelKey: values.model as String,
    if (values.style is String) aiStyleKey: values.style as String,
  };
}
