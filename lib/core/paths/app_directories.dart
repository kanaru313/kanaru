/// Kanaru's per-user directories on Linux, following the XDG Base Directory
/// spec:
///
/// - config: `$XDG_CONFIG_HOME/kanaru`, else `~/.config/kanaru`
/// - data: `$XDG_DATA_HOME/kanaru`, else `~/.local/share/kanaru`
/// - cache: `$XDG_CACHE_HOME/kanaru`, else `~/.cache/kanaru`
///
/// An XDG variable that is unset, empty or relative is ignored (the spec says
/// to ignore relative values). Each resolver returns `null` when neither the
/// variable nor `HOME` gives an absolute path.
///
/// Takes the environment as a map so it can be tested without touching the
/// real one.
library;

String? resolveConfigDirectory(Map<String, String> environment) =>
    _resolve(environment, 'XDG_CONFIG_HOME', '.config');

String? resolveDataDirectory(Map<String, String> environment) =>
    _resolve(environment, 'XDG_DATA_HOME', '.local/share');

String? resolveCacheDirectory(Map<String, String> environment) =>
    _resolve(environment, 'XDG_CACHE_HOME', '.cache');

String? _resolve(
  Map<String, String> environment,
  String variable,
  String homeFallback,
) {
  final base = environment[variable];
  if (base != null && base.startsWith('/')) {
    return '${_trimSlashes(base)}/kanaru';
  }
  final home = environment['HOME'];
  if (home != null && home.startsWith('/')) {
    return '${_trimSlashes(home)}/$homeFallback/kanaru';
  }
  return null;
}

String _trimSlashes(String path) {
  var end = path.length;
  while (end > 1 && path[end - 1] == '/') {
    end--;
  }
  return path.substring(0, end);
}
