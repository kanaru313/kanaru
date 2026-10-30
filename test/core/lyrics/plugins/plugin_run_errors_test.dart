import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_retry.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_errors.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';

Matcher _kind(LyricsFetchKind kind) =>
    isA<LyricsFetchException>().having((e) => e.kind, 'kind', kind);

PluginFetchFailure _fetch(PluginFetchFailureKind kind, {int? retry}) =>
    PluginFetchFailure(kind: kind, retryAfterSec: retry, message: 'm');

void main() {
  group('statuses without a failed fetch', () {
    test('ok is no failure', () {
      expect(
        pluginRunFailure(const PluginRunResult(status: PluginRunStatus.ok)),
        isNull,
      );
      expect(
        () => throwPluginRunFailure(
          const PluginRunResult(status: PluginRunStatus.ok),
        ),
        returnsNormally,
      );
    });

    test('cancelled is abandoned', () {
      expect(
        pluginRunFailure(
          const PluginRunResult(status: PluginRunStatus.cancelled),
        ),
        isA<LyricsRequestAbandoned>(),
      );
    });

    test('busy skips the source: its own signal, not a fetch failure', () {
      final failure = pluginRunFailure(
        const PluginRunResult(status: PluginRunStatus.busy),
      );
      expect(failure, isA<LyricsSourceSkipped>());
      expect(failure, isNot(isA<LyricsFetchException>()));
    });

    test('timeout is network', () {
      expect(
        pluginRunFailure(
          const PluginRunResult(status: PluginRunStatus.timeout),
        ),
        _kind(LyricsFetchKind.network),
      );
    });

    for (final status in [
      PluginRunStatus.memory,
      PluginRunStatus.stack,
      PluginRunStatus.outputTooLarge,
      PluginRunStatus.internal,
    ]) {
      test('${status.name} is invalidResponse', () {
        expect(
          pluginRunFailure(PluginRunResult(status: status)),
          _kind(LyricsFetchKind.invalidResponse),
        );
      });
    }
  });

  group('script errors', () {
    PluginRunResult error(PluginRunErrorKind kind, {int? retry}) =>
        PluginRunResult(
          status: PluginRunStatus.scriptError,
          errorKind: kind,
          retryAfterSec: retry,
        );

    test('without a kind (an exception) is invalidResponse', () {
      expect(
        pluginRunFailure(error(PluginRunErrorKind.none)),
        _kind(LyricsFetchKind.invalidResponse),
      );
    });

    test('server', () {
      expect(
        pluginRunFailure(error(PluginRunErrorKind.server)),
        _kind(LyricsFetchKind.server),
      );
    });

    test('invalidResponse', () {
      expect(
        pluginRunFailure(error(PluginRunErrorKind.invalidResponse)),
        _kind(LyricsFetchKind.invalidResponse),
      );
    });

    test('rateLimited keeps retryAfterSec', () {
      expect(
        pluginRunFailure(error(PluginRunErrorKind.rateLimited, retry: 90)),
        isA<LyricsFetchException>()
            .having((e) => e.kind, 'kind', LyricsFetchKind.rateLimited)
            .having(
              (e) => e.retryAfter,
              'retryAfter',
              const Duration(seconds: 90),
            ),
      );
    });

    test('rateLimited clamps the wait to 1 s .. 15 min, none stays none', () {
      Duration? wait(int? sec) =>
          (pluginRunFailure(error(PluginRunErrorKind.rateLimited, retry: sec))!
                  as LyricsFetchException)
              .retryAfter;
      expect(wait(0), const Duration(seconds: 1));
      expect(wait(100000), const Duration(minutes: 15));
      expect(wait(null), isNull);
    });
  });

  group('a failed fetch of the run', () {
    test('network, blockedHost, notConsented keep their kind', () {
      for (final (fetch, kind) in [
        (PluginFetchFailureKind.network, LyricsFetchKind.network),
        (PluginFetchFailureKind.blockedHost, LyricsFetchKind.blockedHost),
        (PluginFetchFailureKind.notConsented, LyricsFetchKind.notConsented),
        (
          PluginFetchFailureKind.invalidResponse,
          LyricsFetchKind.invalidResponse,
        ),
      ]) {
        expect(
          pluginRunFailure(
            PluginRunResult(
              status: PluginRunStatus.scriptError,
              fetchFailure: _fetch(fetch),
            ),
          ),
          _kind(kind),
        );
      }
    });

    test('invalidRequest is the plugin\'s fault: invalidResponse', () {
      expect(
        pluginRunFailure(
          PluginRunResult(
            status: PluginRunStatus.ok,
            fetchFailure: _fetch(PluginFetchFailureKind.invalidRequest),
          ),
        ),
        _kind(LyricsFetchKind.invalidResponse),
      );
    });

    test('rateLimited carries and clamps the wait', () {
      final failure = pluginRunFailure(
        PluginRunResult(
          status: PluginRunStatus.ok,
          fetchFailure: _fetch(PluginFetchFailureKind.rateLimited, retry: 5000),
        ),
      );
      expect(
        failure,
        isA<LyricsFetchException>()
            .having((e) => e.kind, 'kind', LyricsFetchKind.rateLimited)
            .having((e) => e.retryAfter, 'wait', const Duration(minutes: 15)),
      );
    });

    test('an abandoned fetch is abandoned', () {
      expect(
        pluginRunFailure(
          PluginRunResult(
            status: PluginRunStatus.ok,
            fetchFailure: _fetch(PluginFetchFailureKind.abandoned),
          ),
        ),
        isA<LyricsRequestAbandoned>(),
      );
    });

    test('success([]) after a caught fetch failure is a failure', () {
      final result = PluginRunResult(
        status: PluginRunStatus.ok,
        outputJson: '[]',
        fetchFailure: _fetch(PluginFetchFailureKind.network),
      );
      expect(pluginRunFailure(result), _kind(LyricsFetchKind.network));
      expect(
        () => throwPluginRunFailure(result),
        throwsA(_kind(LyricsFetchKind.network)),
      );
    });

    test('it wins over the script\'s own error kind', () {
      expect(
        pluginRunFailure(
          PluginRunResult(
            status: PluginRunStatus.scriptError,
            errorKind: PluginRunErrorKind.server,
            fetchFailure: _fetch(PluginFetchFailureKind.blockedHost),
          ),
        ),
        _kind(LyricsFetchKind.blockedHost),
      );
    });

    test('a cancelled run is abandoned even with a failed fetch', () {
      expect(
        pluginRunFailure(
          PluginRunResult(
            status: PluginRunStatus.cancelled,
            fetchFailure: _fetch(PluginFetchFailureKind.network),
          ),
        ),
        isA<LyricsRequestAbandoned>(),
      );
    });
  });

  test('failure names for the logs', () {
    expect(
      pluginFailureName(
        const LyricsFetchException(LyricsFetchKind.rateLimited),
      ),
      'rateLimited',
    );
    expect(pluginFailureName(const LyricsRequestAbandoned()), 'abandoned');
    expect(pluginFailureName(const LyricsSourceSkipped()), 'skipped');
  });
}
