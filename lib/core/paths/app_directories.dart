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

/// Longest side, in pixels, of the cover thumbnails the tag reader writes.
/// Also the name of their cache folder, so thumbnails of another size never
/// share a folder with these.
const coverThumbnailSize = 512;

/// Folder of the cover thumbnails: `<cache>/covers/512`. Thumbnails can be
/// rebuilt from the music files, so they belong in the cache directory.
String? resolveCoverCacheDirectory(Map<String, String> environment) {
  final cache = resolveCacheDirectory(environment);
  return cache == null ? null : '$cache/covers/$coverThumbnailSize';
}

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

/// Drops trailing slashes so joining never doubles them; the root `/`
/// becomes empty, giving `/kanaru` rather than `//kanaru`.
String _trimSlashes(String path) {
  var end = path.length;
  while (end > 0 && path[end - 1] == '/') {
    end--;
  }
  return path.substring(0, end);
}
