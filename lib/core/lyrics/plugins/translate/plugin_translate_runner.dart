import 'dart:io';

import '../../../database/library_database.dart';
import '../../../database/lyrics_plugin_queries.dart';
import '../../../lyrics_translation/translation_failure.dart';
import '../../../lyrics_translation/translation_lines.dart';
import '../../../plugin_runtime/plugin_runtime.dart';
import '../../online/lyrics_http.dart';
import '../../online/lyrics_http_retry.dart' show LyricsSleep, realLyricsSleep;
import '../lyrics_plugin_record.dart';
import '../package/plugin_manifest.dart';
import '../package/plugin_translate_spec.dart';
import '../plugin_failure_log.dart';
import '../plugin_fetch_bridge.dart';
import '../plugin_output_reader.dart';
import '../plugin_run_core.dart';
import '../plugin_run_deadline.dart';
import '../plugin_run_log.dart';
import '../store/plugin_config_schema_codec.dart';
import 'plugin_translate_errors.dart';
import 'plugin_translate_gate.dart';
import 'plugin_translate_output.dart';

export 'plugin_translate_output.dart' show PluginTranslatedLine;

const _scriptName = 'translate.js';

/// The song a translate script may use as context.
class PluginTranslateSong {
  const PluginTranslateSong({
    required this.title,
    required this.artist,
    required this.lyrics,
  });

  /// [uniqueLines] joined by newlines; see [lyrics].
  PluginTranslateSong.fromLines({
    required this.title,
    required this.artist,
    required List<String> uniqueLines,
  }) : lyrics = uniqueLines.join('\n');

  final String title;
  final String artist;

  /// All the lyrics of the job, so a model sees the whole song. At most
  /// [maxTranslatedChars] characters are sent.
  final String lyrics;

  Map<String, Object?> toJson() => {
    'title': title,
    'artist': artist,
    'lyrics': _capped(lyrics),
  };

  // At most [maxTranslatedChars] code units, never ending inside a pair.
  static String _capped(String text) {
    if (text.length <= maxTranslatedChars) return text;
    var end = maxTranslatedChars;
    final last = text.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end--;
    return text.substring(0, end);
  }
}

/// What a translate plugin declares, read before the first chunk.
typedef PluginTranslateInfo = ({
  PluginTranslateSpec spec,
  List<String> hosts,
  List<PluginConfigField> config,
});

/// Runs `translate.js` of an installed translate plugin for one chunk of
/// lines and turns what happens into the lines or a [TranslationException].
///
/// * one chunk at a time over the whole app ([PluginTranslateGate]); a chunk
///   whose job is no longer wanted is dropped before it sends;
/// * the script has the plugin's own wall time (`timeoutSec`), its `fetch`
///   calls the time left of the run with no cap per send, no automatic
///   re-send of a busy answer, and only the hosts of the plugin;
/// * `allowed` is asked live before every send and before the chunk starts;
/// * a chunk is never cancelled by the caller once sent (it is billed); an
///   update or uninstall of the plugin still cancels it;
/// * the plugin log gets the failure (or console output) of a run with the
///   language and the size of the chunk, never the lyrics.
class PluginTranslateRunner {
  PluginTranslateRunner({
    required this._core,
    required this._runLog,
    required this._client,
    PluginTranslateGate? gate,
    this._sleep = realLyricsSleep,
    DateTime Function()? clock,
    this._queueAllowance = pluginRunQueueAllowance,
  }) : _gate = gate ?? PluginTranslateGate(),
       _clock = clock ?? DateTime.now;

  final PluginRunCore _core;
  final PluginRunLog _runLog;
  final HttpClient Function() _client;
  final PluginTranslateGate _gate;
  final LyricsSleep _sleep;
  final DateTime Function() _clock;

  /// How long a run may wait for a free worker before its own wall time.
  final Duration _queueAllowance;

  /// What the plugin declares, from its database record (the package is read
  /// only for the script). Throws [TranslationException]: `server` for a
  /// plugin that is missing, removed or not a translate plugin,
  /// `invalidResponse` for a record with no translate spec (also written to
  /// the plugin log).
  Future<PluginTranslateInfo> spec(String installId) async {
    final row = await _core.db.lyricsPluginById(installId);
    if (row == null ||
        row.removedAt != null ||
        PluginKind.fromValue(row.kind)?.isTranslation != true) {
      throw const TranslationException(TranslationFailureKind.server);
    }
    final record = LyricsPluginRecord.fromRow(row);
    final declared = record.translate;
    if (declared == null) {
      _record(
        row,
        const {},
        TranslationFailureKind.invalidResponse,
        'the plugin record has no translate spec',
      );
      throw const TranslationException(TranslationFailureKind.invalidResponse);
    }
    return (spec: declared, hosts: record.hosts, config: record.config);
  }

  /// Translates [lines] into [to] and returns exactly one item per line.
  /// [song] is context for the script. [allowed] is asked before the chunk
  /// starts and before every send (nothing goes out when it is false).
  /// [stillWanted] is asked once the chunk reaches the front of the line;
  /// when false, [TranslationSuperseded] is thrown and nothing is sent.
  /// [configAppend] is the song's note for `customInstruction` (see
  /// `PluginRunCore.run`). [configOverride] replaces select config values
  /// (the tier's model and style), filtered by the run core.
  Future<List<PluginTranslatedLine>> translateChunk(
    String installId,
    List<String> lines,
    String to,
    PluginTranslateSong? song, {
    required bool Function() allowed,
    bool Function()? stillWanted,
    Map<String, String> configAppend = const {},
    Map<String, Object?> configOverride = const {},
  }) async {
    final info = await spec(installId);
    final timeout = Duration(seconds: info.spec.timeoutSec);
    final input = <String, Object?>{
      'lines': lines,
      'to': to,
      'song': ?song?.toJson(),
    };
    // What the log keeps of the input: sizes, not text.
    final query = {
      'to': to,
      'lines': lines.length,
      'chars': lines.fold<int>(0, (sum, line) => sum + line.length),
    };
    return _gate.run(stillWanted ?? () => true, () async {
      // Asked again here: the wait in line can be long.
      if (!allowed()) {
        throw const TranslationException(TranslationFailureKind.blocked);
      }
      final outcome = await _core.run(
        installId: installId,
        kind: PluginKind.translate,
        entry: (package) => package.translateScript,
        input: input,
        configAppend: configAppend,
        configOverride: configOverride,
        timeout: timeout,
        // Counted from here: the gate was passed.
        deadline: _queueAllowance + timeout,
        http: (row) => LyricsHttp.forPluginTranslate(
          LyricsPluginRecord.fromRow(row).hosts,
          _client(),
          overallTimeout: pluginTranslateMaxWallTime,
          allowed: allowed,
          sleep: _sleep,
        ),
      );
      return _finish(outcome, lines, to, query);
    });
  }

  List<PluginTranslatedLine> _finish(
    PluginRunOutcome outcome,
    List<String> lines,
    String to,
    Map<String, Object?> query,
  ) {
    final row = outcome.row;
    // Missing, removed, of another kind or being changed: a retry may work.
    if (row == null) {
      throw const TranslationException(TranslationFailureKind.server);
    }
    // A required field is empty: nothing ran, nothing is logged.
    if (outcome.state == PluginRunState.needsConfig) {
      throw const TranslationException(TranslationFailureKind.needsConfig);
    }
    if (outcome.state == PluginRunState.setupFailed) {
      final kind = translateSetupFailureKind(
        timedOut: outcome.timedOut,
        secret: outcome.secret,
      );
      _record(row, const {}, kind, outcome.reason, query: query);
      throw TranslationException(kind);
    }
    // Stopped by an update or uninstall: nothing is logged.
    if (outcome.stopped) {
      throw const TranslationException(TranslationFailureKind.server);
    }
    final result = outcome.result!;
    final config = outcome.config;
    var failure = translateFailureKind(
      result,
      hasEmptySecret: _hasEmptySecret(row, config),
    );
    final notes = <String>[];
    var problem = '';
    List<PluginTranslatedLine>? value;
    if (failure == null) {
      try {
        value = readTranslateOutput(result.outputJson, lines, to, notes);
      } on PluginOutputException catch (e) {
        problem = e.reason;
        failure = TranslationFailureKind.invalidResponse;
      }
    }
    final skipped =
        result.status == PluginRunStatus.cancelled ||
        result.status == PluginRunStatus.busy;
    if (!skipped) {
      _record(
        row,
        outcome.logConfig,
        failure,
        problem.isNotEmpty
            ? problem
            : (result.jsError?.message ?? result.errorMessage),
        query: query,
        stack: result.jsError?.stack,
        console: [...result.logs, for (final n in notes) 'dropped: $n'],
        requests: outcome.requests,
        failed: failure != null,
      );
    }
    if (failure != null) throw TranslationException(failure);
    return value!;
  }

  // True when a secret field of the plugin has no value in [config]: a
  // refused key is then "no key" rather than "wrong key".
  bool _hasEmptySecret(LyricsPluginRow row, PluginConfigMap config) =>
      decodePluginConfigSchema(row.configSchema).any(
        (field) =>
            isSecretField(field) &&
            (config[field.key] is! String ||
                (config[field.key]! as String).trim().isEmpty),
      );

  // Writes the run to the plugin's log (and, for a failure, the app log).
  void _record(
    LyricsPluginRow row,
    PluginConfigMap config,
    TranslationFailureKind? failure,
    String message, {
    Map<String, Object?> query = const {},
    String? stack,
    List<String> console = const [],
    List<PluginRequestRecord> requests = const [],
    bool failed = true,
  }) => recordPluginRun(
    _runLog,
    PluginRunLogEvent(
      time: _clock(),
      installId: row.installId,
      pluginName: row.name,
      version: '${row.version}',
      script: _scriptName,
      query: query,
      kind: failure?.name ?? pluginRunOkKind,
      message: failure == null ? '' : message,
      stack: stack,
      console: console,
      requests: requests,
    ),
    config,
    schema: decodePluginConfigSchema(row.configSchema),
    failed: failed && failure != null,
    appLogLabel: 'Translate plugin',
  );
}
