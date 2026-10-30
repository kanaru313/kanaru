import 'package:flutter_test/flutter_test.dart';
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
}
