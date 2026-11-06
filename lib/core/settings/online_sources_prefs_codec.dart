import '../lyrics/plugins/store/plugin_install_id.dart';
import 'online_sources_prefs.dart';
import 'settings_codec_values.dart';

const _noticeAcknowledgedKey = 'noticeAcknowledged';
const _knownKeys = {_noticeAcknowledgedKey};

/// Most acknowledged plugins kept; a hand-edited file cannot grow the set.
const maxAcknowledgedSourcePlugins = 64;

/// Reads the `onlineSources` object. The second value holds the keys this
/// version does not know, plus (under `noticeAcknowledged`) the items that
/// are not plugin ids, so that saving keeps them. A missing or wrong-typed
/// list gives no consent.
(OnlineSourcesPrefs, Map<String, Object?>) decodeOnlineSourcesPrefs(
  Object? json,
) {
  final map = objectOrEmpty(json);
  final (acknowledged, others) = _decodeAcknowledged(
    map[_noticeAcknowledgedKey],
  );
  return (
    OnlineSourcesPrefs(noticeAcknowledged: acknowledged),
    {
      ...unknownEntries(map, _knownKeys),
      if (others.isNotEmpty) _noticeAcknowledgedKey: others,
    },
  );
}

(Set<String>, List<Object?>) _decodeAcknowledged(Object? json) {
  if (json is! List) return (const {}, const []);
  final ids = <String>{};
  final others = <Object?>[];
  for (final item in json) {
    if (item is String && pluginInstallIdPattern.hasMatch(item)) {
      if (ids.length < maxAcknowledgedSourcePlugins) ids.add(item);
    } else {
      others.add(item);
    }
  }
  return (Set.unmodifiable(ids), others);
}

/// The `onlineSources` object, with [extra] (unknown keys and items that are
/// not plugin ids) carried over.
Map<String, Object?> encodeOnlineSourcesPrefs(
  OnlineSourcesPrefs prefs, {
  Map<String, Object?> extra = const {},
}) {
  final others = extra[_noticeAcknowledgedKey];
  return {
    ...extra,
    _noticeAcknowledgedKey: [
      ...prefs.noticeAcknowledged,
      if (others is List) ...others,
    ],
  };
}
