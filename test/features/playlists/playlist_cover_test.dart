import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/playlist_cover_keys.dart';
import 'package:kanaru/shared/widgets/cover_art.dart';
import 'package:kanaru/shared/widgets/placeholder_colors.dart';
import 'package:kanaru/shared/widgets/playlist_cover.dart';
import 'package:material_ui/material_ui.dart';

/// A cover key in the shape the indexer writes: `<ab>/<ab…>.jpg`.
String keyOf(String shard) => '$shard/$shard${'0' * 62}.jpg';

/// A 1x1 PNG; the decoder sniffs the format, so the `.jpg` name is fine.
final tinyImage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kanaru_playlist_cover_test');
    PaintingBinding.instance.imageCache.clear();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('pickCollageKeys', () {
    test('takes the first four distinct non-null keys in order', () {
      expect(pickCollageKeys([null, 'a', 'a', 'b', null, 'c', 'd', 'e']), [
        'a',
        'b',
        'c',
        'd',
      ]);
    });

    test('stops looking after the scan limit', () {
      // The 64th non-null key is the last one looked at; 'd' is never seen.
      final keys = <String?>[
        for (var i = 0; i < playlistCollageScanLimit - 1; i++)
          i.isEven ? 'a' : 'b',
        'c',
        'd',
      ];
      keys.insert(3, null);
      expect(pickCollageKeys(keys), ['a', 'b', 'c']);
      expect(pickCollageKeys([...keys, 'e']), ['a', 'b', 'c']);
    });

    test('empty and repeated input', () {
      expect(pickCollageKeys(const []), isEmpty);
      expect(pickCollageKeys(['a', 'a']), ['a']);
    });
  });

  group('PlaylistCover', () {
    const seed = 'playlist:1';

    /// Writes real images for [shards] and returns their keys.
    List<String> writeCovers(
      List<String> shards, {
      Set<String> skip = const {},
    }) {
      final keys = <String>[];
      for (final shard in shards) {
        final key = keyOf(shard);
        keys.add(key);
        if (skip.contains(shard)) continue;
        File('${dir.path}/$key')
          ..createSync(recursive: true)
          ..writeAsBytesSync(tinyImage);
      }
      return keys;
    }

    Future<void> pump(
      WidgetTester tester,
      List<String> keys, {
      double size = 120,
      bool coversOn = true,
    }) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          coverCacheDirectoryProvider.overrideWithValue(
            coversOn ? dir.path : null,
          ),
        ],
        child: MaterialApp(
          home: Center(
            child: PlaylistCover(coverKeys: keys, size: size, seed: seed),
          ),
        ),
      ),
    );

    List<Image> images(WidgetTester tester) =>
        tester.widgetList<Image>(find.byType(Image)).toList();

    testWidgets('no keys shows the placeholder icon and no image', (
      tester,
    ) async {
      await pump(tester, const []);

      expect(find.byIcon(Icons.queue_music), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.getSize(find.byType(PlaylistCover)), const Size(120, 120));
    });

    testWidgets('one to three keys show the first cover at full size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final count in [1, 3]) {
        final keys = writeCovers(['ab', 'cd', 'ef'].take(count).toList());
        await pump(tester, keys);

        final shown = images(tester);
        expect(shown, hasLength(1), reason: '$count keys');
        final resized = shown.single.image as ResizeImage;
        expect(resized.width, coverDecodeWidth(120 * 1.0));
        expect(
          (resized.imageProvider as FileImage).file.path,
          '${dir.path}/${keys.first}',
        );
      }
    });

    testWidgets('four keys show a 2x2 grid decoded at tile size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final keys = writeCovers(['aa', 'bb', 'cc', 'dd']);
      await pump(tester, keys, size: 200);

      final shown = images(tester);
      expect(shown, hasLength(4));
      for (final image in shown) {
        expect((image.image as ResizeImage).width, coverDecodeWidth(100 * 2));
      }
      // Reading order: top-left, top-right, bottom-left, bottom-right.
      final tops = shown
          .map((i) => tester.getTopLeft(find.byWidget(i)))
          .toList();
      expect(tops[1].dx, greaterThan(tops[0].dx));
      expect(tops[1].dy, tops[0].dy);
      expect(tops[2].dy, greaterThan(tops[0].dy));
      expect(tester.getSize(find.byType(PlaylistCover)), const Size(200, 200));
    });

    testWidgets('a missing file falls back to the placeholder color', (
      tester,
    ) async {
      final keys = writeCovers(['aa', 'bb', 'cc', 'dd'], skip: {'cc'});
      await pump(tester, keys);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      // errorBuilder renders inside the Image, so all four stay.
      expect(images(tester), hasLength(4));
      final (background, _) = placeholderColors(
        Theme.of(tester.element(find.byType(PlaylistCover))).colorScheme,
        seed,
      );
      final fallbacks = find.descendant(
        of: find.byType(PlaylistCover),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == background,
        ),
      );
      expect(fallbacks, findsOneWidget);
      expect(find.byIcon(Icons.queue_music), findsNothing);
    });

    testWidgets('covers off shows one placeholder with the icon', (
      tester,
    ) async {
      await pump(tester, [
        keyOf('aa'),
        keyOf('bb'),
        keyOf('cc'),
        keyOf('dd'),
      ], coversOn: false);

      expect(find.byIcon(Icons.queue_music), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}
