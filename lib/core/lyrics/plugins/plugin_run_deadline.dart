import '../../plugin_runtime/plugin_runtime.dart';

/// Longest a script may run once a worker has it (the runtime's own limit).
const pluginScriptWallTime = Duration(seconds: 15);

/// What a run may wait for a free worker before the caller gives up: four
/// workers and sixteen queued jobs, each taking up to [pluginScriptWallTime],
/// would be a minute, so this is a generous slice of it. The runtime's clock
/// starts only when a worker picks the job up; the outer clock starts when
/// the run is asked for.
const pluginRunQueueAllowance = Duration(seconds: 45);

/// Longest one run may take from the call: queue wait plus script time.
const pluginRunOuterDeadline = Duration(seconds: 60);

/// Runs [request] on [runtime] and gives up after [deadline]. On expiry the
/// run is cancelled (so its worker and its pending sends stop) and the
/// result is a `timeout`, which counts as a network failure like a script
/// timeout. [timedOut] tells that case from a cancel by the caller.
Future<({PluginRunResult result, bool timedOut})> runWithDeadline(
  PluginRuntime runtime,
  PluginRunRequest request, {
  required PluginFetcher fetch,
  required PluginCancel cancel,
  required Duration deadline,
}) async {
  var timedOut = false;
  final result = await runtime
      .run(request, fetch: fetch, cancel: cancel)
      .timeout(
        deadline,
        onTimeout: () {
          timedOut = true;
          cancel.cancel();
          return const PluginRunResult(
            status: PluginRunStatus.timeout,
            errorMessage: 'The plugin did not finish in time',
          );
        },
      );
  return (result: result, timedOut: timedOut);
}
