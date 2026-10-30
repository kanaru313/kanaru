import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../../plugin_runtime/plugin_runtime.dart';
import '../package/plugin_package_limits.dart';
import '../package/plugin_package_problem.dart';

/// Longest time reading a package file may take.
const pluginFileReadLimit = Duration(seconds: 10);

/// Reads the plugin zip at [path]. The path must be a regular file (links are
/// followed; a pipe or device is refused). The file is streamed and reading
/// stops at one byte past the package cap, whatever its reported length.
/// Throws [PluginPackageProblem]: `tooLarge`, or `notZip` (detail says why)
/// for a file that is not regular, cannot be read, or takes too long.
Future<Uint8List> readPluginFile(
  String path, {
  int maxBytes = maxPluginPackageBytes,
  Duration limit = pluginFileReadLimit,
  Stream<List<int>> Function(String path)? open,
}) async {
  final FileStat stat;
  try {
    stat = await FileStat.stat(path);
  } on FileSystemException {
    throw const PluginPackageProblem(
      PluginPackageProblemKind.notZip,
      detail: 'unreadable',
    );
  }
  if (stat.type != FileSystemEntityType.file) {
    throw const PluginPackageProblem(
      PluginPackageProblemKind.notZip,
      detail: 'not a regular file',
    );
  }
  final bytes = BytesBuilder(copy: false);
  final done = Completer<void>();
  late final StreamSubscription<List<int>> subscription;
  subscription = (open ?? (p) => File(p).openRead())(path).listen(
    (chunk) {
      bytes.add(chunk);
      if (bytes.length > maxBytes && !done.isCompleted) {
        subscription.cancel();
        done.complete();
      }
    },
    onError: (Object error) {
      if (!done.isCompleted) done.completeError(error);
    },
    onDone: () {
      if (!done.isCompleted) done.complete();
    },
    cancelOnError: true,
  );
  try {
    await done.future.timeout(limit);
  } on TimeoutException {
    // Not awaited: cancelling waits for a blocked open or read (a stalled
    // network mount) and would hang the caller past the limit.
    unawaited(subscription.cancel());
    throw const PluginPackageProblem(
      PluginPackageProblemKind.notZip,
      detail: 'read timed out',
    );
  } on FileSystemException {
    throw const PluginPackageProblem(
      PluginPackageProblemKind.notZip,
      detail: 'unreadable',
    );
  }
  if (bytes.length > maxBytes) {
    throw const PluginPackageProblem(PluginPackageProblemKind.tooLarge);
  }
  return bytes.takeBytes();
}

/// A runtime that gives up on a stuck syntax check after [limit]. The reader
/// treats the resulting error as "cannot check" and refuses the package, so a
/// hung native call never holds up an install.
class TimeLimitedCheckRuntime implements PluginRuntime {
  const TimeLimitedCheckRuntime(
    this._inner, {
    this.limit = const Duration(seconds: 10),
  });

  final PluginRuntime _inner;
  final Duration limit;

  @override
  Future<PluginScriptProblem?> check(String fileName, String code) =>
      _inner.check(fileName, code).timeout(limit);

  @override
  Future<PluginRunResult> run(
    PluginRunRequest request, {
    required PluginFetcher fetch,
    PluginCancel? cancel,
  }) => _inner.run(request, fetch: fetch, cancel: cancel);
}
