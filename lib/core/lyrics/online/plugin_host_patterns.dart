import 'lyrics_provider_registry.dart' show lyricsHostProblem;

/// The prefix of a wildcard host entry: `*.` + a base host name.
const pluginHostWildcardPrefix = '*.';

/// Most wildcard entries one plugin may list.
const maxPluginHostWildcards = 10;

/// Bases a wildcard may not use: shared-hosting suffixes under which anyone
/// can register a name, so `*.<base>` would reach every tenant's site.
const pluginHostDeniedWildcardBases = {
  'workers.dev',
  'pages.dev',
  'github.io',
  'gitlab.io',
  'netlify.app',
  'vercel.app',
  'herokuapp.com',
  'appspot.com',
  'web.app',
  'firebaseapp.com',
  'cloudfront.net',
  'azurewebsites.net',
  'blogspot.com',
  'onrender.com',
  'fly.dev',
  'glitch.me',
};

/// One DNS label a wildcard may stand for: 1 to 63 of `[a-z0-9-]`, not
/// starting or ending with `-`.
final _label = RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$');

/// Why [pattern] may not be a plugin host entry, or `null` when it may.
///
/// An entry is either a plain host name that [lyricsHostProblem] accepts, or
/// `*.` followed by such a name (so the base has at least two labels). A `*`
/// anywhere else is refused. The deny list and the per-plugin rules are
/// checked by [pluginHostListProblem].
String? pluginHostPatternProblem(String pattern) {
  if (pattern.startsWith(pluginHostWildcardPrefix)) {
    final base = pattern.substring(pluginHostWildcardPrefix.length);
    if (base.contains('*')) return 'wildcard must be a leading *. label';
    return lyricsHostProblem(base);
  }
  if (pattern.contains('*')) return 'wildcard must be a leading *. label';
  return lyricsHostProblem(pattern);
}

/// Why a host entry of a plugin may not be listed.
enum PluginHostRefusal {
  /// Not a public DNS name (an IP, `localhost`, a single label…).
  notPublic,

  /// A `*` that is not one leading `*.` label over a public name.
  badWildcard,

  /// A wildcard in a plugin that is not a source plugin.
  wildcardNotAllowed,

  /// A wildcard over a shared-hosting suffix
  /// ([pluginHostDeniedWildcardBases]).
  sharedHostingWildcard,

  /// More than [maxPluginHostWildcards] distinct wildcard entries.
  tooManyWildcards,
}

/// The first entry of a plugin's [hosts] that may not be listed, with the
/// reason, or `null` when every entry may. [hosts] are expected trimmed and
/// lower-cased, as the manifest and catalog parsers store them.
///
/// Each entry must pass [pluginHostPatternProblem]. Wildcard entries are
/// refused unless [wildcardsAllowed] (source plugins only), a wildcard base
/// may not be in [pluginHostDeniedWildcardBases], and at most
/// [maxPluginHostWildcards] distinct wildcard entries are allowed; the entry
/// reported for that is the first one over the cap.
({String entry, PluginHostRefusal reason})? pluginHostListProblem(
  List<String> hosts, {
  required bool wildcardsAllowed,
}) {
  final wildcards = <String>{};
  for (final entry in hosts) {
    if (pluginHostPatternProblem(entry) != null) {
      final reason = entry.contains('*')
          ? PluginHostRefusal.badWildcard
          : PluginHostRefusal.notPublic;
      return (entry: entry, reason: reason);
    }
    if (!entry.startsWith(pluginHostWildcardPrefix)) continue;
    if (!wildcardsAllowed) {
      return (entry: entry, reason: PluginHostRefusal.wildcardNotAllowed);
    }
    final base = entry.substring(pluginHostWildcardPrefix.length);
    if (pluginHostDeniedWildcardBases.contains(base)) {
      return (entry: entry, reason: PluginHostRefusal.sharedHostingWildcard);
    }
    wildcards.add(entry);
    if (wildcards.length > maxPluginHostWildcards) {
      return (entry: entry, reason: PluginHostRefusal.tooManyWildcards);
    }
  }
  return null;
}

/// The hosts a request may reach, built from host entries (plain names and
/// `*.` wildcards).
///
/// [allows] lower-cases the host, refuses one ending with `.`, and then
/// accepts it when it equals a plain entry, or when it is exactly one label
/// (`[a-z0-9-]{1,63}`, no leading or trailing `-`) in front of a wildcard's
/// base. The base itself (the apex) is not matched by its wildcard, nor is a
/// name two or more labels below it.
///
/// Entries are not validated here beyond this: the parsers refuse bad
/// entries before a plugin is installed. As a second guard, an entry holding
/// a `*` anywhere but a leading `*.` is ignored, and so is a wildcard whose
/// base [lyricsHostProblem] refuses or that is on the deny list.
class PluginHostSet {
  PluginHostSet(Iterable<String> entries) {
    for (final entry in entries) {
      if (entry.startsWith(pluginHostWildcardPrefix)) {
        final base = entry.substring(pluginHostWildcardPrefix.length);
        if (pluginHostPatternProblem(entry) == null &&
            !pluginHostDeniedWildcardBases.contains(base)) {
          _wildcardBases.add(base);
        }
      } else if (!entry.contains('*')) {
        _plain.add(entry);
      }
    }
  }

  final _plain = <String>{};
  final _wildcardBases = <String>{};

  /// Whether a request to [host] (a URI's host) may be made.
  bool allows(String host) {
    final name = host.toLowerCase();
    if (name.isEmpty || name.endsWith('.')) return false;
    if (_plain.contains(name)) return true;
    final dot = name.indexOf('.');
    if (dot <= 0) return false;
    return _wildcardBases.contains(name.substring(dot + 1)) &&
        _label.hasMatch(name.substring(0, dot));
  }
}
