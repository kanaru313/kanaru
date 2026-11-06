import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_reader.dart';
import 'package:kanaru/core/lyrics/plugins/store/lyrics_plugin_installer.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/core/sources/source_notice_sweep.dart';
import 'package:kanaru/core/sources/source_plugin_records.dart';

import '../lyrics/plugins/store/store_test_env.dart';

PluginPackage _sourcePackage(String name) => PluginPackage(
  manifest: PluginManifest(
    kind: PluginKind.source,
    apiVersion: 1,
    name: name,
    version: 1,
    hosts: const ['api.example.com'],
    searchScript: 'search.js',
    streamScript: 'stream.js',
    author: 'someone',
  ),
  files: const {'search.js': '// search', 'stream.js': '// stream'},
);

/// Polls until [condition] holds, failing the test after five seconds.
Future<void> _until(bool Function() condition) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (clock.elapsed > const Duration(seconds: 5)) fail('never reached');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late StoreEnv store;

  setUp(() async {
    store = await StoreEnv.create();
    addTearDown(store.dispose);
  });

  ProviderContainer make({
    AppSettings initial = const AppSettings(),
    bool withDb = true,
  }) {
    final container = ProviderContainer(
      overrides: <Override>[
        initialSettingsProvider.overrideWithValue(initial),
        libraryDatabaseProvider.overrideWithValue(withDb ? store.db : null),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Set<String> acknowledged(ProviderContainer c) =>
      c.read(settingsProvider).onlineSources.noticeAcknowledged;

  test(
    'uninstalling a plugin removes its id from the accepted notices',
    () async {
      final kept = await store.controller.installPackage(
        _sourcePackage('Kept'),
        const PluginInstallSource.file('kept.zip'),
      );
      final gone = await store.controller.installPackage(
        _sourcePackage('Gone'),
        const PluginInstallSource.file('gone.zip'),
      );
      final c = make();
      c.listen(sourceNoticeSweepProvider, (_, _) {});
      c.read(settingsProvider.notifier)
        ..acknowledgeSourceNotice(kept.installId)
        ..acknowledgeSourceNotice(gone.installId);
      await _until(() => c.read(sourcePluginRecordsProvider).hasValue);
      expect(acknowledged(c), {kept.installId, gone.installId});

      await store.controller.uninstall(gone.installId);

      await _until(() => acknowledged(c).length == 1);
      expect(acknowledged(c), {kept.installId});
    },
  );

  test('an id of a plugin that is not installed is dropped once the list is '
      'read', () async {
    final c = make(
      initial: const AppSettings(
        onlineSources: OnlineSourcesPrefs(
          noticeAcknowledged: {'plugin-000000000000'},
        ),
      ),
    );

    c.listen(sourceNoticeSweepProvider, (_, _) {});

    await _until(() => acknowledged(c).isEmpty);
  });

  test('a lyrics plugin is not a live source plugin', () async {
    final lyrics = await store.controller.installPackage(
      testPackage(name: 'L'),
      const PluginInstallSource.file('l.zip'),
    );
    final c = make(
      initial: AppSettings(
        onlineSources: OnlineSourcesPrefs(
          noticeAcknowledged: {lyrics.installId},
        ),
      ),
    );

    c.listen(sourceNoticeSweepProvider, (_, _) {});

    await _until(() => acknowledged(c).isEmpty);
  });

  test('without a database nothing is dropped', () async {
    const start = AppSettings(
      onlineSources: OnlineSourcesPrefs(
        noticeAcknowledged: {'plugin-000000000000'},
      ),
    );
    final c = make(initial: start, withDb: false);

    c.listen(sourceNoticeSweepProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(c.read(sourcePluginRecordsProvider).hasError, isTrue);
    expect(c.read(settingsProvider), start);
  });

  test('records list only live source plugins, in install order', () async {
    final first = await store.controller.installPackage(
      _sourcePackage('A'),
      const PluginInstallSource.file('a.zip'),
    );
    await store.controller.installPackage(
      testPackage(name: 'L'),
      const PluginInstallSource.file('l.zip'),
    );
    final second = await store.controller.installPackage(
      _sourcePackage('B'),
      const PluginInstallSource.file('b.zip'),
    );
    final removed = await store.controller.installPackage(
      _sourcePackage('C'),
      const PluginInstallSource.file('c.zip'),
    );
    await store.controller.uninstall(removed.installId);
    final c = make();
    c.listen(sourcePluginRecordsProvider, (_, _) {});
    expect(c.read(sourcePluginRecordsProvider).isLoading, isTrue);

    await _until(() => c.read(sourcePluginRecordsProvider).hasValue);

    expect(
      c.read(sourcePluginRecordsProvider).requireValue.map((r) => r.installId),
      [first.installId, second.installId],
    );
  });
}
