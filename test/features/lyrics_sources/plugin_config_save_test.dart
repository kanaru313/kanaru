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

  test('a refused save with nowhere to tell the user is logged', () async {
    final saved = await savePluginConfigValueWith(
      controller: FakePlugins()..configResult = PluginConfigWrite.tooLarge,
      messenger: null,
      l10n: en,
      installId: idA,
      key: 'name',
      value: 'x',
    );

    expect(saved, isFalse);
    expect(
      logs.where(
        (r) =>
            r.level == Level.WARNING &&
            r.message.contains('was not saved and nothing could show it'),
      ),
      hasLength(1),
    );
  });

  test('a saved value logs nothing', () async {
    final saved = await savePluginConfigValueWith(
      controller: FakePlugins(),
      messenger: null,
      l10n: en,
      installId: idA,
      key: 'name',
      value: 'x',
    );

    expect(saved, isTrue);
    expect(logs, isEmpty);
  });

  test('onSaved runs only when the value was saved', () async {
    var calls = 0;
    for (final result in [
      PluginConfigWrite.written,
      PluginConfigWrite.invalidValue,
    ]) {
      await savePluginConfigValueWith(
        controller: FakePlugins()..configResult = result,
        messenger: null,
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
