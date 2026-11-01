import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_errors.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';
import 'package:kanaru/core/secrets/secret_store.dart';

TranslationFailureKind? _kind(
  PluginRunResult result, {
  bool emptySecret = false,
}) => translateFailureKind(result, hasEmptySecret: emptySecret);

PluginRunResult _error(
  PluginRunErrorKind kind, {
  PluginFetchFailureKind? fetch,
}) => PluginRunResult(
  status: PluginRunStatus.scriptError,
  errorKind: kind,
  fetchFailure: fetch == null
      ? null
      : PluginFetchFailure(kind: fetch, message: 'm'),
);

void main() {
  group('statuses', () {
    test('cancelled and busy are server', () {
      for (final status in [PluginRunStatus.cancelled, PluginRunStatus.busy]) {
        expect(
          _kind(PluginRunResult(status: status)),
          TranslationFailureKind.server,
        );
      }
    });

    test('timeout is network', () {
      expect(
        _kind(const PluginRunResult(status: PluginRunStatus.timeout)),
        TranslationFailureKind.network,
      );
    });

    test(
      'memory, stack, output too large and internal are invalidResponse',
      () {
        for (final status in [
          PluginRunStatus.memory,
          PluginRunStatus.stack,
          PluginRunStatus.outputTooLarge,
          PluginRunStatus.internal,
        ]) {
          expect(
            _kind(PluginRunResult(status: status)),
            TranslationFailureKind.invalidResponse,
          );
        }
      },
    );

    test('ok is no failure, even with a fetch the script caught', () {
      expect(_kind(const PluginRunResult(status: PluginRunStatus.ok)), isNull);
      expect(
        _kind(
          const PluginRunResult(
            status: PluginRunStatus.ok,
            fetchFailure: PluginFetchFailure(
              kind: PluginFetchFailureKind.network,
              message: 'm',
            ),
          ),
        ),
        isNull,
      );
    });
  });

  group('script error kinds', () {
    test('auth is noKey with an empty secret and badKey with a filled one', () {
      final result = _error(PluginRunErrorKind.auth);
      expect(_kind(result, emptySecret: true), TranslationFailureKind.noKey);
      expect(_kind(result), TranslationFailureKind.badKey);
    });

    test('quota, rateLimited and invalidResponse map to their namesakes', () {
      expect(
        _kind(_error(PluginRunErrorKind.quota)),
        TranslationFailureKind.quotaExceeded,
      );
      expect(
        _kind(_error(PluginRunErrorKind.rateLimited)),
        TranslationFailureKind.rateLimited,
      );
      expect(
        _kind(_error(PluginRunErrorKind.invalidResponse)),
        TranslationFailureKind.invalidResponse,
      );
    });

    test('server and none without a failed fetch', () {
      expect(
        _kind(_error(PluginRunErrorKind.server)),
        TranslationFailureKind.server,
      );
      expect(
        _kind(_error(PluginRunErrorKind.none)),
        TranslationFailureKind.invalidResponse,
      );
    });

    test('server and none with a failed fetch go by the fetch kind', () {
      const expected = {
        PluginFetchFailureKind.network: TranslationFailureKind.network,
        PluginFetchFailureKind.blockedHost: TranslationFailureKind.blocked,
        PluginFetchFailureKind.notConsented: TranslationFailureKind.blocked,
        PluginFetchFailureKind.rateLimited: TranslationFailureKind.rateLimited,
        PluginFetchFailureKind.invalidRequest:
            TranslationFailureKind.invalidResponse,
        PluginFetchFailureKind.invalidResponse:
            TranslationFailureKind.invalidResponse,
        PluginFetchFailureKind.abandoned: TranslationFailureKind.server,
      };
      for (final MapEntry(key: fetch, value: kind) in expected.entries) {
        for (final error in [
          PluginRunErrorKind.server,
          PluginRunErrorKind.none,
        ]) {
          expect(
            _kind(_error(error, fetch: fetch)),
            kind,
            reason: '$error $fetch',
          );
        }
      }
    });

    test('a script kind wins over a failed fetch', () {
      expect(
        _kind(
          _error(
            PluginRunErrorKind.quota,
            fetch: PluginFetchFailureKind.network,
          ),
        ),
        TranslationFailureKind.quotaExceeded,
      );
    });
  });

  group('setup', () {
    test('secret store failures', () {
      expect(
        translateSetupFailureKind(
          timedOut: false,
          secret: SecretStoreFailure.locked,
        ),
        TranslationFailureKind.keyStoreLocked,
      );
      expect(
        translateSetupFailureKind(
          timedOut: false,
          secret: SecretStoreFailure.unavailable,
        ),
        TranslationFailureKind.keyStoreUnavailable,
      );
    });

    test('a slow load is network, an unreadable package invalidResponse', () {
      expect(
        translateSetupFailureKind(timedOut: true),
        TranslationFailureKind.network,
      );
      expect(
        translateSetupFailureKind(timedOut: false),
        TranslationFailureKind.invalidResponse,
      );
    });
  });
}
