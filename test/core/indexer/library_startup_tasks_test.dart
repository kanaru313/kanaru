import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/core/indexer/library_startup_tasks.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_tag_reader.dart';

void main() {
  late Directory tmp;
  late String root;
  late LibraryDatabase db;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('startup_tasks_test');
    root = '${tmp.resolveSymbolicLinksSync()}/music';
    Directory(root).createSync();
    File('$root/a.mp3').writeAsStringSync('x');
    db = LibraryDatabase(NativeDatabase.memory());
    await db.addRoots([root], now: 1);
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  ProviderContainer containerFor({
    bool hasRoots = true,
    bool hasDb = true,
    AppSettings settings = const AppSettings(),
  }) {
    final container = ProviderContainer(
      overrides: [
        ...LibraryStartup(db: hasDb ? db : null, hasRoots: hasRoots).overrides,
        tagReaderProvider.overrideWithValue(FakeTagReader()),
        initialSettingsProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('scans quietly when enabled, with a database and a folder', () async {
    final container = containerFor();

    await runLibraryStartupTasks(container);

    final state = container.read(libraryIndexerProvider);
    expect(state, isA<IndexerFinished>());
    expect((state as IndexerFinished).quiet, isTrue);
    expect(state.summary.added, 1);
  });

  test('does nothing when the setting is off', () {
    final container = containerFor(
      settings: const AppSettings(rescanOnStartup: false),
    );

    expect(runLibraryStartupTasks(container), isNull);
    expect(container.read(libraryIndexerProvider), isA<IndexerIdle>());
  });

  test('does nothing without a database', () {
    final container = containerFor(hasDb: false);

    expect(runLibraryStartupTasks(container), isNull);
    expect(container.read(libraryIndexerProvider), isA<IndexerIdle>());
  });

  test('does nothing without a folder', () {
    final container = containerFor(hasRoots: false);

    expect(runLibraryStartupTasks(container), isNull);
    expect(container.read(libraryIndexerProvider), isA<IndexerIdle>());
  });

  test('marks a library that already has folders as onboarded', () {
    final container = containerFor(
      settings: const AppSettings(rescanOnStartup: false),
    );

    runLibraryStartupTasks(container);

    expect(container.read(settingsProvider).libraryOnboarded, isTrue);
  });

  test('leaves a library without folders un-onboarded', () {
    final container = containerFor(hasRoots: false);

    runLibraryStartupTasks(container);

    expect(container.read(settingsProvider).libraryOnboarded, isFalse);
  });
}
