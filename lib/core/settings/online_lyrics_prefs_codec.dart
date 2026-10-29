import 'online_lyrics_prefs.dart';
import 'settings_codec_values.dart';

const _autoFetchKey = 'autoFetch';
const _noticeAcknowledgedKey = 'noticeAcknowledged';

/// Written by older versions to turn on `.lrc` writing on a pick. It is
/// known so that it is dropped on read instead of carried along as an
/// unknown key, and is never written.
const _legacyWriteLrcKey = 'writeLrc';
const _knownKeys = {_autoFetchKey, _legacyWriteLrcKey, _noticeAcknowledgedKey};

/// Reads the `onlineLyrics` object; each key falls back on its own. The
/// second value holds the keys this version does not know, plus (under
/// `noticeAcknowledged`) the entries that are not strings, so that saving
/// keeps them.
///
/// `autoFetch` is read as off unless an automatic-lookup consent key is
/// acknowledged, so a hand-edited file cannot start requests without the
/// notice.
(OnlineLyricsPrefs, Map<String, Object?>) decodeOnlineLyricsPrefs(
  Object? json,
) {
  final map = objectOrEmpty(json);
  const d = OnlineLyricsPrefs();
  final list = map[_noticeAcknowledgedKey];
  final entries = list is List ? list : const <Object?>[];
  final acknowledged = Set<String>.unmodifiable(entries.whereType<String>());
  final others = [
    for (final entry in entries)
      if (entry is! String) entry,
  ];
  return (
    OnlineLyricsPrefs(
      autoFetch:
          boolOr(map[_autoFetchKey], d.autoFetch) &&
          acknowledged.any(isAutoConsentKey),
      noticeAcknowledged: acknowledged,
    ),
    {
      ...unknownEntries(map, _knownKeys),
      if (others.isNotEmpty) _noticeAcknowledgedKey: others,
    },
  );
}

/// The `onlineLyrics` object, with [extra] (unknown keys and entries)
/// carried over.
Map<String, Object?> encodeOnlineLyricsPrefs(
  OnlineLyricsPrefs prefs, {
  Map<String, Object?> extra = const {},
}) {
  final others = extra[_noticeAcknowledgedKey];
  return {
    ...extra,
    _autoFetchKey: prefs.autoFetch,
    _noticeAcknowledgedKey: [
      ...(prefs.noticeAcknowledged.toList()..sort()),
      if (others is List) ...others,
    ],
  };
}
