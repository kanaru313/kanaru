import '../core/database/language_tags.dart';
import 'artist_summaries.dart' show preferredSpelling;
import 'sort_compare.dart';

/// One language row (Languages list).
class LanguageSummary {
  const LanguageSummary({
    required this.key,
    required this.name,
    required this.songCount,
    required this.raws,
  });

  /// `languageKey(name)`; identifies the language page.
  final String key;

  /// The [preferredSpelling] among the stored values that name the language;
  /// the fallback label of a language with no translation.
  final String name;

  /// Tracks whose stored language names this language (a track with several
  /// languages in one string counts once for each).
  final int songCount;

  /// The stored language strings that name this language, to query its
  /// tracks.
  final List<String> raws;
}

/// The list rows for [counts] (stored language string and its tracks), one
/// per [languageKey], sorted by key. A string naming several languages counts
/// for each; keys in [hiddenLanguageKeys] get no row. Tracks without a
/// language tag are not in [counts] and appear nowhere.
List<LanguageSummary> buildLanguageSummaries(
  List<({String raw, int count})> counts,
) {
  final names = <String, String>{};
  final songs = <String, int>{};
  final raws = <String, Set<String>>{};
  for (final (:raw, :count) in counts) {
    for (final name in splitLanguages(raw)) {
      final key = languageKey(name);
      if (hiddenLanguageKeys.contains(key)) continue;
      names[key] = preferredSpelling(names[key], name);
      songs[key] = (songs[key] ?? 0) + count;
      (raws[key] ??= {}).add(raw);
    }
  }
  final keys = names.keys.toList()..sort(compareCodePoints);
  return [
    for (final key in keys)
      LanguageSummary(
        key: key,
        name: names[key]!,
        songCount: songs[key]!,
        raws: raws[key]!.toList()..sort(compareCodePoints),
      ),
  ];
}
