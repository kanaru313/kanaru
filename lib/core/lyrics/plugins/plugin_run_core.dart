import 'dart:async';
import 'dart:convert';

import '../../database/library_database.dart';
import '../../database/lyrics_plugin_queries.dart';
import '../../plugin_runtime/plugin_runtime.dart';
import '../../secrets/secret_store.dart';
import '../online/lyrics_http.dart';
import 'plugin_fetch_bridge.dart';
import 'plugin_package_loader.dart';
import 'plugin_run_deadline.dart';
import 'plugin_run_registry.dart';
import 'plugin_run_setup.dart';
import 'plugin_storage_writeback.dart';
import 'store/lyrics_plugin_dirs.dart';

/// How far a run of [PluginRunCore] got.
enum PluginRunState {
  /// Nothing ran and nothing is to be reported: the plugin is missing,
  /// removed, of another kind, being changed, lacks the script, or an update
  /// or uninstall stopped the run.
  skipped,

  /// The package or the settings could not be loaded, or loading took too
  /// long.
  setupFailed,

  /// The script ran (or was cut short); see [PluginRunOutcome.result].
  finished,
}

/// What [PluginRunCore.run] found. It logs nothing: each front maps the
/// outcome to its own errors and log line.
class PluginRunOutcome {
  const PluginRunOutcome.skipped()
    : state = PluginRunState.skipped,
      row = null,
      reason = '',
      timedOut = false,
      secret = null,
      result = null,
      stopped = false,
      requests = const [],
      config = const {};

  const PluginRunOutcome.setupFailed({
    required LyricsPluginRow this.row,
    required this.reason,
    required this.timedOut,
    this.secret,
  }) : state = PluginRunState.setupFailed,
       result = null,
       stopped = false,
       requests = const [],
       config = const {};

  const PluginRunOutcome.finished({
    required LyricsPluginRow this.row,
    required PluginRunResult this.result,
    required this.timedOut,
    required this.stopped,
    required this.requests,
    required this.config,
  }) : state = PluginRunState.finished,
       reason = '',
       secret = null;

  final PluginRunState state;

  /// The plugin's record as the run read it (not for a skipped run).
  final LyricsPluginRow? row;

  /// Setup failure text; holds no value, safe to log.
  final String reason;

  /// The outer deadline passed (while loading or while running).
  final bool timedOut;

  /// Why the secret store failed during setup, if it did.
  final SecretStoreFailure? secret;

  final PluginRunResult? result;

  /// Cancelled from outside (an update or uninstall), not by the deadline.
  /// Nothing was written back.
  final bool stopped;

  /// The `fetch` calls of the run, in order.
  final List<PluginRequestRecord> requests;

  /// The config the run saw (secrets included): only for hiding values in
  /// the log.
  final PluginConfigMap config;
}

/// The part of a script run that does not depend on what the script is for:
/// register in [PluginRunRegistry], read the record, load the package and
/// settings, run with an outer deadline and write the plugin's storage back
/// while the record is unchanged. Lyrics and translate fronts map the
/// [PluginRunOutcome].
class PluginRunCore {
  PluginRunCore({
    required this.db,
    required this._runtime,
    required this._runs,
    required this._dirs,
    required this._loadConfig,
    PluginPackageLoader? packages,
    this.outerDeadline = pluginRunOuterDeadline,
  }) : packages = packages ?? PluginPackageLoader();

  final LibraryDatabase db;
  final PluginRuntime _runtime;
  final PluginRunRegistry _runs;
  final LyricsPluginDirs _dirs;
  final Future<PluginConfigMap> Function(String installId) _loadConfig;

  /// The package cache every front shares.
  final PluginPackageLoader packages;

  /// Default outer deadline, covering loading and running.
  final Duration outerDeadline;

  /// The package of [row] from the shared cache. Throws
  /// [PluginPackageUnreadable], also for a malformed folder name.
  Future<LoadedPluginPackage> loadPackage(LyricsPluginRow row) {
    try {
      return packages.load(row.packageDir, _dirs.resolve(row.packageDir));
    } on ArgumentError {
      throw const PluginPackageUnreadable(
        'the package folder name is not valid',
      );
    }
  }

  /// Runs the script [entry] picks from the package of [installId], which
  /// must be of [kind]. [input] is the script's argument; [http] answers its
  /// `fetch` calls and is made once the record is read. [timeout] is the
  /// script's wall time (null: the runtime default); [deadline] replaces
  /// [outerDeadline] for this run.
  Future<PluginRunOutcome> run({
    required String installId,
    required PluginKind kind,
    required String? Function(LoadedPluginPackage package) entry,
    required Object? input,
    required LyricsHttp Function(LyricsPluginRow row) http,
    Duration? timeout,
    Duration? deadline,
  }) async {
    final cancel = PluginCancel();
    final unregister = _runs.register(installId, cancel);
    if (unregister == null) return const PluginRunOutcome.skipped();
    try {
      return await _run(
        installId,
        kind,
        entry,
        input,
        http,
        timeout,
        deadline ?? outerDeadline,
        cancel,
      );
    } finally {
      unregister();
    }
  }

  Future<PluginRunOutcome> _run(
    String installId,
    PluginKind kind,
    String? Function(LoadedPluginPackage) entry,
    Object? input,
    LyricsHttp Function(LyricsPluginRow) makeHttp,
    Duration? timeout,
    Duration outer,
    PluginCancel cancel,
  ) async {
    final row = await db.lyricsPluginById(installId);
    if (row == null || row.removedAt != null || row.kind != kind.value) {
      return const PluginRunOutcome.skipped();
    }
    PluginRunOutcome failedSetup(
      String reason, {
      bool timedOut = false,
      SecretStoreFailure? secret,
    }) => PluginRunOutcome.setupFailed(
      row: row,
      reason: reason,
      timedOut: timedOut,
      secret: secret,
    );

    // The outer clock covers the loading as well as the run.
    final clock = Stopwatch()..start();
    final PluginRunSetup setup;
    try {
      setup = await loadPluginRunSetup(
        db: db,
        packages: packages,
        dirs: _dirs,
        loadConfig: _loadConfig,
        record: row,
      ).timeout(outer);
    } on PluginPackageUnreadable catch (e) {
      // Stopped by an update or uninstall while loading: nothing to report.
      if (cancel.isCancelled) return const PluginRunOutcome.skipped();
      return failedSetup(e.reason);
    } on PluginRunSetupException catch (e) {
      if (cancel.isCancelled) return const PluginRunOutcome.skipped();
      return failedSetup(e.reason, secret: e.secret);
    } on TimeoutException {
      if (cancel.isCancelled) return const PluginRunOutcome.skipped();
      return failedSetup('loading the plugin took too long', timedOut: true);
    }
    final config = setup.config;
    if (cancel.isCancelled) return const PluginRunOutcome.skipped();

    final entryName = entry(setup.package);
    // A package without this script is not a plugin of this front.
    if (entryName == null) return const PluginRunOutcome.skipped();
    final bridge = PluginFetchBridge(makeHttp(row));
    final left = outer - clock.elapsed;
    final (:result, :timedOut) = await runWithDeadline(
      _runtime,
      PluginRunRequest(
        files: setup.package.files,
        entry: entryName,
        inputJson: jsonEncode(input),
        timeout: timeout,
        config: config,
        storageJson: setup.storageJson,
      ),
      fetch: bridge.call,
      cancel: cancel,
      deadline: left.isNegative ? Duration.zero : left,
    );
    // Cancelled from outside (an uninstall or update): nothing is written.
    final stopped = cancel.isCancelled && !timedOut;
    if (!stopped && result.storage != null) {
      await savePluginStorage(db, installId, result.storage!, row.updatedAt);
    }
    return PluginRunOutcome.finished(
      row: row,
      result: result,
      timedOut: timedOut,
      stopped: stopped,
      requests: bridge.requests,
      config: config,
    );
  }
}
