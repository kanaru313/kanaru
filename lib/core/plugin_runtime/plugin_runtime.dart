import 'plugin_fetch_types.dart';
import 'plugin_run_result.dart';

export 'plugin_fetch_types.dart';
export 'plugin_run_result.dart';

/// One file of a plugin's `src/` folder, already read and size-checked.
class PluginSourceFile {
  const PluginSourceFile({required this.name, required this.code});

  /// File name without a folder, e.g. `search.js`.
  final String name;
  final String code;
}

/// What to run.
class PluginRunRequest {
  const PluginRunRequest({
    required this.files,
    required this.entry,
    required this.inputJson,
    this.timeout,
    this.config = const {},
    this.storageJson = '',
  });

  /// All files of the package's `src/` folder; `load()` reaches only these.
  final List<PluginSourceFile> files;

  /// Name of the file to run first; must be in [files].
  final String entry;

  /// JSON text that becomes the argument of the script's `execute(input)`.
  final String inputJson;

  /// Wall-time limit; null means the runtime's own maximum. A smaller value
  /// is meant for tests. The clock starts when a worker begins the run, so
  /// the caller keeps its own outer deadline.
  final Duration? timeout;

  /// The plugin's configuration (secrets included), readable by the script.
  final Map<String, String> config;

  /// The plugin's stored map as a JSON object of strings; empty for none.
  final String storageJson;
}

/// Stops a run from outside. One token can serve several runs one after the
/// other; once cancelled it stays cancelled, so a later run ends cancelled
/// without running any script.
class PluginCancel {
  bool _cancelled = false;
  final Set<void Function()> _listeners = {};

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List.of(_listeners)) {
      // One failing listener must not stop the others or reach the caller.
      try {
        listener();
      } on Object {
        continue;
      }
    }
  }

  /// Runs [listener] when the token is cancelled. Used by runtimes only.
  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);
}

/// A syntax error found by [PluginRuntime.check].
class PluginScriptProblem {
  const PluginScriptProblem({required this.message, this.line});

  final String message;

  /// 1-based line; null when unknown.
  final int? line;
}

/// Runs plugin scripts in a sandbox. The test seam of everything above it.
abstract interface class PluginRuntime {
  /// Runs `request.entry`. [fetch] answers the script's `fetch` calls.
  /// Never throws for a failed run; the failure is in the result's status.
  Future<PluginRunResult> run(
    PluginRunRequest request, {
    required PluginFetcher fetch,
    PluginCancel? cancel,
  });

  /// Compiles [code] as a classic script named [fileName] without running
  /// it. Null when it parses, else the first syntax problem. Throws when the
  /// native library cannot load or the bridge fails: null would claim the
  /// script is valid when it was never checked.
  Future<PluginScriptProblem?> check(String fileName, String code);
}
