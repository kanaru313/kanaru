import 'dart:async';
import 'dart:ui';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/cover_colors/cover_palette.dart';
import 'package:kanaru/core/cover_colors/playing_cover_palette_provider.dart';
import 'package:kanaru/core/cover_colors/rust_cover_color_extractor.dart';
import 'package:kanaru/core/database/cover_color_queries.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/player/playing_track_art.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_cover_color_extractor.dart';

const _dir = '/cache/covers/512';

/// Stands in for the playing track's art.
class _Art extends Notifier<String?> {
  @override
  String? build() => null;

  void play(String? art) => state = art;
}

final _artProvider = NotifierProvider<_Art, String?>(_Art.new);

void main() {
  late LibraryDatabase db;
  late FakeCoverColorExtractor extractor;
  late ProviderContainer container;

  ProviderContainer start({bool on = true, String? initialArt}) {
    container = ProviderContainer(
      overrides: [
        ...LibraryStartup(db: db, coverCacheDirectory: _dir).overrides,
        initialSettingsProvider.overrideWithValue(
          AppSettings(display: DisplayPrefs(colorFromCover: on)),
        ),
        playingTrackArtProvider.overrideWith((ref) => ref.watch(_artProvider)),
        coverColorExtractorProvider.overrideWithValue(extractor),
      ],
    );
    addTearDown(container.dispose);
    // Listened, as the app's theme listens to it.
    container.listen(appCoverPaletteProvider, (_, _) {});
    if (initialArt != null) {
      container.read(_artProvider.notifier).play(initialArt);
    }
    return container;
  }

  void play(String? art) => container.read(_artProvider.notifier).play(art);

  Future<CoverPalette?> palette() =>
      container.read(playingCoverPaletteProvider.future);

  Future<int> storedRows() async =>
      (await db.select(db.coverColors).get()).length;

  setUp(() {
    db = LibraryDatabase(NativeDatabase.memory());
    extractor = FakeCoverColorExtractor();
  });
  tearDown(() => db.close());

  test('off: nothing is read, worked out or stored', () async {
    start(on: false, initialArt: '$_dir/${keyFor(1)}');
    expect(await palette(), isNull);
    expect(extractor.calls, isEmpty);
    expect(await storedRows(), 0);
    expect(container.read(appCoverPaletteProvider), isNull);
  });

  test('stored colors are used without the native code', () async {
    final key = keyFor(1);
    await db.upsertCoverColors([sampleFor(key, seed: 0xFFCC2233)]);
    start(initialArt: '$_dir/$key');
    final found = await palette();
    expect(found!.seed, const Color(0xFFCC2233));
    expect(extractor.calls, isEmpty);
  });

  test('missing colors are worked out at once and stored', () async {
    final key = keyFor(1);
    start(initialArt: '$_dir/$key');
    final found = await palette();
    expect(found, isNotNull);
    expect(extractor.calls.single.$1, [key]);
    expect(extractor.calls.single.$2, isFalse, reason: 'not in background');
    expect(await db.coverPaletteOf(key), found);

    play('$_dir/${keyFor(2)}');
    await palette();
    play('$_dir/$key');
    await palette();
    expect(extractor.calls.length, 2, reason: 'the first cover is stored');
  });

  test('a gray cover has colors but no seed', () async {
    final key = keyFor(1);
    extractor.colors[key] = sampleFor(key, seed: 0);
    start(initialArt: '$_dir/$key');
    final found = await palette();
    expect(found!.seed, isNull);
    expect(found.colors, isNotEmpty);
    expect(container.read(appCoverPaletteProvider)?.seed, isNull);
  });

  test('art that is not one of our thumbnails gives no colors', () async {
    for (final art in [null, '/music/cover.jpg', '$_dir/../x.jpg']) {
      start(initialArt: art);
      expect(await palette(), isNull, reason: art);
    }
    expect(extractor.calls, isEmpty);
  });

  test('a failing extractor gives no colors and is not asked again', () async {
    final key = keyFor(1);
    extractor.error = StateError('native gone');
    start(initialArt: '$_dir/$key');
    expect(await palette(), isNull);
    play(null);
    await palette();
    play('$_dir/$key');
    expect(await palette(), isNull);
    expect(extractor.calls.length, 1);
  });

  test('a cover that fails is not stored', () async {
    final key = keyFor(1);
    extractor.colors[key] = null;
    start(initialArt: '$_dir/$key');
    expect(await palette(), isNull);
    expect(await storedRows(), 0);
  });

  test('the app keeps the old colors while the next ones load', () async {
    final red = keyFor(1), blue = keyFor(2);
    await db.upsertCoverColors([sampleFor(red, seed: 0xFFCC0000)]);
    start(initialArt: '$_dir/$red');
    await palette();
    expect(
      container.read(appCoverPaletteProvider)?.seed,
      const Color(0xFFCC0000),
    );

    extractor.colors[blue] = sampleFor(blue, seed: 0xFF0000CC);
    extractor.gate = Completer<void>();
    play('$_dir/$blue');
    await pumpEventQueue();
    expect(
      container.read(appCoverPaletteProvider)?.seed,
      const Color(0xFFCC0000),
      reason: 'still loading',
    );

    extractor.gate!.complete();
    await palette();
    await pumpEventQueue();
    expect(
      container.read(appCoverPaletteProvider)?.seed,
      const Color(0xFF0000CC),
    );

    play(null);
    await palette();
    await pumpEventQueue();
    expect(container.read(appCoverPaletteProvider), isNull);
  });

  test(
    'a track change mid-way neither blocks nor stores the old cover',
    () async {
      final a = keyFor(1), b = keyFor(2);
      extractor.gate = Completer<void>();
      start(initialArt: '$_dir/$a');
      final first = palette();
      await pumpEventQueue();
      expect(extractor.calls.length, 1);
      play('$_dir/$b');
      // The app listens, so the provider rebuilds for the new track at once.
      await pumpEventQueue();
      extractor.gate!.complete();
      extractor.gate = null;
      await first;
      await palette();
      expect(
        await db.coverPaletteOf(a),
        isNull,
        reason: 'stale run stores nothing',
      );

      play('$_dir/$a');
      expect(await palette(), isNotNull, reason: 'not skipped for the session');
      expect(await db.coverPaletteOf(a), isNotNull);
    },
  );

  test('turning the setting off mid-way stores nothing', () async {
    final a = keyFor(1);
    extractor.gate = Completer<void>();
    start(initialArt: '$_dir/$a');
    final first = palette();
    await pumpEventQueue();
    container
        .read(settingsProvider.notifier)
        .setDisplay(const DisplayPrefs(colorFromCover: false));
    await pumpEventQueue();
    extractor.gate!.complete();
    await first;
    expect(await palette(), isNull);
    expect(await storedRows(), 0);
  });

  test('colors already known when the app starts are shown at once', () async {
    final key = keyFor(1);
    await db.upsertCoverColors([sampleFor(key, seed: 0xFFCC0000)]);
    start(initialArt: '$_dir/$key');
    await palette();
    expect(
      container.read(appCoverPaletteProvider)?.seed,
      const Color(0xFFCC0000),
    );
  });
}
