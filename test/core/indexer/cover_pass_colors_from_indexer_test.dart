import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/cover_colors/rust_cover_color_extractor.dart';
import 'package:kanaru/core/database/cover_color_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import '../cover_colors/fake_cover_color_extractor.dart';
import 'fake_tag_reader.dart';

void main() {
  late Directory tmp;
  late String root, covers;
  late LibraryDatabase db;
  late FakeTagReader reader;
  late FakeCoverColorExtractor colors;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('indexer_colors_test');
    final base = tmp.resolveSymbolicLinksSync();
    root = '$base/music';
    covers = '$base/cache/covers/512';
    Directory(root).createSync();
    db = LibraryDatabase(NativeDatabase.memory());
    reader = FakeTagReader()..coverDirectory = covers;
    colors = FakeCoverColorExtractor();
    await db.addRoots([root], now: 1);
    for (final name in ['a.mp3', 'b.mp3', 'c.mp3']) {
      File('$root/$name').writeAsStringSync('x');
    }
    reader.coverByName
      ..['a.mp3'] = 'red'
      ..['b.mp3'] = 'red'
      ..['c.mp3'] = 'blue';
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  ProviderContainer start({required bool colorFromCover}) {
    final container = ProviderContainer(
      overrides: [
        ...LibraryStartup(db: db, coverCacheDirectory: covers).overrides,
        tagReaderProvider.overrideWithValue(reader),
        coverColorExtractorProvider.overrideWithValue(colors),
        initialSettingsProvider.overrideWithValue(
          AppSettings(display: DisplayPrefs(colorFromCover: colorFromCover)),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<Set<String>> stored() async => {
    for (final row in await db.select(db.coverColors).get()) row.coverKey,
  };

  test('a scan with colors on stores the colors of every cover', () async {
    final container = start(colorFromCover: true);
    await container.read(libraryIndexerProvider.notifier).scan();

    expect(await stored(), {fakeCoverKey('red'), fakeCoverKey('blue')});
    expect(colors.calls.single.$2, isTrue, reason: 'background threads');
    expect(await db.coverPaletteOf(fakeCoverKey('red')), isNotNull);
  });

  test('a scan with colors off works out and stores nothing', () async {
    final container = start(colorFromCover: false);
    await container.read(libraryIndexerProvider.notifier).scan();

    expect(colors.calls, isEmpty);
    expect(await stored(), isEmpty);
    expect((await db.select(db.tracks).get()).map((t) => t.coverKey).toSet(), {
      fakeCoverKey('red'),
      fakeCoverKey('blue'),
    }, reason: 'thumbnails are made as before');
  });

  test('turning colors on later fills them in at the next scan', () async {
    final container = start(colorFromCover: false);
    final indexer = container.read(libraryIndexerProvider.notifier);
    await indexer.scan();
    expect(await stored(), isEmpty);

    final settings = container.read(settingsProvider.notifier);
    settings.setDisplay(
      container.read(settingsProvider).display.copyWith(colorFromCover: true),
    );
    await indexer.scan();
    expect(await stored(), {fakeCoverKey('red'), fakeCoverKey('blue')});
  });
}
