/// Where Kanaru writes its log files on Linux:
/// `$XDG_CACHE_HOME/kanaru/logs`, or `~/.cache/kanaru/logs` when
/// `XDG_CACHE_HOME` is unset, empty or relative (the XDG spec says to ignore
/// relative values). `null` when neither variable gives a usable directory,
/// in which case logging stays on the console only.
///
/// Takes the environment as a map so it can be tested without touching the
/// real one.
String? resolveLogDirectory(Map<String, String> environment) {
  final cache = environment['XDG_CACHE_HOME'];
  if (cache != null && cache.startsWith('/')) {
    return '${_trimSlashes(cache)}/kanaru/logs';
  }
  final home = environment['HOME'];
  if (home != null && home.startsWith('/')) {
    return '${_trimSlashes(home)}/.cache/kanaru/logs';
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
