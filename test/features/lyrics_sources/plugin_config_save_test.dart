import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/features/lyrics_sources/plugin_config_save.dart';
import 'package:logging/logging.dart';

import 'lyrics_sources_harness.dart';

void main() {
  late List<LogRecord> logs;
  late Level? previousLevel;

  setUp(() {
    logs = [];
    previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final sub = Logger.root.onRecord.listen(logs.add);
    addTearDown(() {
      sub.cancel();
      Logger.root.level = previousLevel!;
    });
  });

  test('a refused save returns its message and logs nothing', () async {
    final message = await savePluginConfigValueWith(
      controller: FakePlugins()..configResult = PluginConfigWrite.tooLarge,
      l10n: en,
      installId: idA,
      key: 'name',
      value: 'x',
    );

    expect(message.message, en.pluginConfigTooLarge);
    expect(message.retryable, isFalse);
    expect(logs, isEmpty);
  });

  test('a saved value returns no message and logs nothing', () async {
    final message = await savePluginConfigValueWith(
      controller: FakePlugins(),
      l10n: en,
      installId: idA,
      key: 'name',
      value: 'x',
    );

    expect(message.saved, isTrue);
    expect(logs, isEmpty);
  });

  test('an exception is logged and reported as a failed save', () async {
    final message = await savePluginConfigValueWith(
      controller: _ThrowingPlugins(),
      l10n: en,
      installId: idA,
      key: 'name',
      value: 'x',
    );

    expect(message.message, en.pluginConfigSaveFailed);
    expect(message.retryable, isTrue);
    expect(logs.where((r) => r.level == Level.WARNING), hasLength(1));
  });

  test('onSaved runs only when the value was saved', () async {
    var calls = 0;
    for (final result in [
      PluginConfigWrite.written,
      PluginConfigWrite.invalidValue,
    ]) {
      await savePluginConfigValueWith(
        controller: FakePlugins()..configResult = result,
        l10n: en,
        installId: idA,
        key: 'name',
        value: 'x',
        onSaved: () => calls++,
      );
    }
    expect(calls, 1);
  });

  test('a saved translate setting clears that service failures', () {
    final jobs = _RecordingJobs();
    final container = ProviderContainer(
      overrides: [translationJobsProvider.overrideWith(() => jobs)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(translationJobsProvider.notifier);

    forgetTranslationFailures(notifier, idA);
    forgetTranslationFailures(notifier, 'not an id');

    expect(jobs.cleared.map((s) => s.value), [idA]);
  });
}

class _RecordingJobs extends TranslationJobs {
  final cleared = <TranslationServiceId>[];

  @override
  void clearFailures(TranslationServiceId service) => cleared.add(service);
}

class _ThrowingPlugins extends FakePlugins {
  @override
  Future<PluginConfigWrite> setConfigValue(
    String installId,
    String key,
    Object? value,
  ) async => throw StateError('boom');
}
