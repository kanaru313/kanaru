import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../lyrics_translation/translation_failure.dart';
import '../../online/online_lyrics_http_factory.dart'
    show lyricsHttpClientProvider;
import '../plugin_log_paths.dart';
import '../plugin_run_log.dart';
import '../plugin_script_runner_provider.dart';
import 'plugin_translate_gate.dart';
import 'plugin_translate_runner.dart';

/// The one gate of translate runs. Never rebuilt (no watched input), so a
/// rebuild of the runner cannot let two translate runs go at once.
final pluginTranslateGateProvider = Provider<PluginTranslateGate>(
  (ref) => PluginTranslateGate(),
);

/// Runs translate plugins. Shares the package cache of the lyrics runner
/// (one loader for every plugin kind). `null` while the library database or
/// the data folder is unavailable.
final pluginTranslateRunnerProvider = Provider<PluginTranslateRunner?>((ref) {
  final scripts = ref.watch(pluginScriptRunnerProvider);
  final logDir = ref.watch(lyricsPluginLogDirProvider);
  if (scripts == null || logDir == null) return null;
  return PluginTranslateRunner(
    core: scripts.core,
    runLog: PluginRunLog(logDir),
    // Read per chunk, like the lyrics client: the same public-only pinned
    // client, but restricted to the plugin's own hosts. A chunk that starts
    // after the container went away fails like a server error instead of
    // throwing a StateError.
    client: () {
      try {
        return ref.read(lyricsHttpClientProvider);
      } on StateError {
        throw const TranslationException(TranslationFailureKind.server);
      }
    },
    gate: ref.watch(pluginTranslateGateProvider),
  );
});
