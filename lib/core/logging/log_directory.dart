import '../paths/app_directories.dart';

/// Where Kanaru writes its log files on Linux:
/// `$XDG_CACHE_HOME/kanaru/logs`, or `~/.cache/kanaru/logs` when
/// `XDG_CACHE_HOME` is unset, empty or relative. `null` when neither variable
/// gives a usable directory, in which case logging stays on the console only.
String? resolveLogDirectory(Map<String, String> environment) {
  final cache = resolveCacheDirectory(environment);
  return cache == null ? null : '$cache/logs';
}
