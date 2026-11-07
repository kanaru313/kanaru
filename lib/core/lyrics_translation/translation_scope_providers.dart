import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:logging/logging.dart';

import '../database/library_startup.dart';
import '../database/lyric_translation_queries.dart';
import '../lyrics/plugins/lyrics_sources_provider.dart';
import '../settings/settings_provider.dart';
import 'queue_translation_choice.dart';
import 'translation_scope.dart';
import 'translation_service.dart';

final _log = Logger('translation');

/// Every song's own service choice, by lyrics content hash. Not auto-dispose:
/// jobs read it synchronously and must not see "loading" after the first
/// load. Loading means "not known yet"; a failed read is logged once and
/// counts as no choices; without a library database it is empty.
final songTranslationOverridesProvider =
    StreamProvider<Map<String, SongTranslationOverride>>((ref) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) {
        return Stream.value(const <String, SongTranslationOverride>{});
      }
      var logged = false;
      return db.watchSongTranslationOverrides().transform(
        StreamTransformer<
          List<SongTranslationOverride>,
          Map<String, SongTranslationOverride>
        >.fromHandlers(
          handleData: (rows, sink) =>
              sink.add({for (final row in rows) row.hash: row}),
          handleError: (error, _, sink) {
            if (!logged) {
              logged = true;
              _log.warning(
                'reading the song translation choices failed: '
                '${error.runtimeType}',
              );
            }
            sink.add(const <String, SongTranslationOverride>{});
          },
        ),
      );
    }, retry: (_, _) => null);

/// Reads the providers [translationChoiceFor] needs: `ref.watch` in a
/// controller, `ref.read` in a job.
typedef ProviderGetter = T Function<T>(ProviderListenable<T> provider);

/// The one place that gathers the inputs of the translation choice of the
/// lyrics text [hash]; the controller passes `ref.watch`, jobs `ref.read`, so
/// both apply the same rule. Null means "not known yet": the plugin records
/// or the song choices are still loading, or the records failed to read (the
/// caller tells that apart). The controller selects only [hash]'s row, so a
/// change to another song's row does not rebuild it.
TranslationChoice? translationChoiceFor(ProviderGetter get, String hash) =>
    _choiceFor(get, hash, omit: null);

/// What [translationChoiceFor] would answer if the [omit] tier had no choice:
/// where "use the default again" lands. Same inputs, same rule. [omit] must be
/// [TranslationScope.song] or [TranslationScope.queue].
TranslationChoice? translationChoiceWithout(
  ProviderGetter get,
  String hash,
  TranslationScope omit,
) => _choiceFor(get, hash, omit: omit);

TranslationChoice? _choiceFor(
  ProviderGetter get,
  String hash, {
  required TranslationScope? omit,
}) {
  final prefs = get(settingsProvider.select((s) => s.translation));
  final records = get(translatePluginRecordsProvider);
  final song = get(
    songTranslationOverridesProvider.select((a) => a.whenData((m) => m[hash])),
  );
  if (!records.hasValue || records.hasError || !song.hasValue) return null;
  final live = {
    for (final r in records.requireValue)
      ?TranslationServiceId.tryParse(r.installId),
  };
  final override = song.value;
  final service = override == null
      ? null
      : TranslationServiceId.tryParse(override.service);
  return resolveTranslationChoice(
    defaultService: prefs.service,
    allChosenAt: prefs.allChosenAt,
    live: live,
    precedence: prefs.scopePrecedence,
    song: omit == TranslationScope.song || override == null || service == null
        ? null
        : ScopedTranslationChoice(
            service: service,
            tune: _decodeTune(override.tuneJson),
            chosenAt: override.chosenAt,
          ),
    queue: omit == TranslationScope.queue
        ? null
        : get(queueTranslationChoiceProvider),
  );
}

/// [translationChoiceFor] with `ref.read`, for code that acts at one moment
/// (jobs). Reads only providers that stay alive.
TranslationChoice? readTranslationChoiceFor(Ref ref, String hash) =>
    translationChoiceFor(ref.read, hash);

/// `{"model": ..., "style": ...}`; anything unreadable is no tune.
Map<String, String> _decodeTune(String? json) {
  if (json == null) return const {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return const {};
    return {
      for (final e in decoded.entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    };
  } on FormatException {
    return const {};
  }
}
