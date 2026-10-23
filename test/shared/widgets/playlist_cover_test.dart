import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/shared/widgets/cover_art.dart';
import 'package:kanaru/shared/widgets/playlist_cover.dart';
import 'package:material_ui/material_ui.dart';

/// A cover key in the shape the indexer writes: `<ab>/<ab…>.jpg`.
String _keyOf(String shard) => '$shard/$shard${'0' * 62}.jpg';

/// A 1x1 PNG; the decoder sniffs the format, so the `.jpg` name is fine.
final _tinyImage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kanaru_collage_test');
    PaintingBinding.instance.imageCache.clear();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  const shards = ['aa', 'bb', 'cc', 'dd', 'ee'];

  /// Writes real images for the first [count] shards and returns their keys.
  List<String> writeCovers(int count) => [
    for (final shard in shards.take(count))
      () {
        final key = _keyOf(shard);
        File('${dir.path}/$key')
          ..createSync(recursive: true)
          ..writeAsBytesSync(_tinyImage);
        return key;
      }(),
  ];

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
          child: PlaylistCover(coverKeys: keys, size: size, seed: 'playlist:1'),
        ),
      ),
    ),
  );

  /// The visible (clipped) cell of each tile: the parent `ClipRect` box.
  List<Rect> cells(WidgetTester tester) => [
    for (final e
        in find
            .descendant(
              of: find.byType(PlaylistCover),
              matching: find.byType(ClipRect),
            )
            .evaluate())
      tester.getRect(find.byWidget(e.widget)),
  ];

  /// Each cover is drawn square at its cell's largest side, centered on the
  /// cell: the overflow is a centre crop.
  void expectCenterCrop(WidgetTester tester, List<Rect> cells) {
    final art = find.byType(CoverArt);
    expect(art, findsNWidgets(cells.length));
    for (var i = 0; i < cells.length; i++) {
      final side = cells[i].width > cells[i].height
          ? cells[i].width
          : cells[i].height;
      expect(
        tester.getRect(art.at(i)),
        Rect.fromCenter(center: cells[i].center, width: side, height: side),
      );
    }
  }

  testWidgets('two covers are two vertical halves', (tester) async {
    await pump(tester, writeCovers(2));

    expect(find.byType(CoverArt), findsNWidgets(2));
    final c = cells(tester);
    expect(c, hasLength(2));
    expect(c[0].size, const Size(60, 120));
    expect(c[1].size, const Size(60, 120));
    expect(c[1].left, c[0].right);
    expect(c[1].top, c[0].top);
    expectCenterCrop(tester, c);
  });

  testWidgets('three covers are a left half and two right quarters', (
    tester,
  ) async {
    await pump(tester, writeCovers(3));

    expect(find.byType(CoverArt), findsNWidgets(3));
    final c = cells(tester);
    expect(c, hasLength(3));
    expect(c[0].size, const Size(60, 120));
    expect(c[1].size, const Size(60, 60));
    expect(c[2].size, const Size(60, 60));
    expect(c[1].left, c[0].right);
    expect(c[2].left, c[0].right);
    expect(c[2].top, c[1].bottom);
    expectCenterCrop(tester, c);
  });

  testWidgets('four covers are a 2x2 grid; extra keys are ignored', (
    tester,
  ) async {
    await pump(tester, writeCovers(5));

    expect(find.byType(CoverArt), findsNWidgets(4));
    final c = cells(tester);
    expect(c.map((r) => r.size), everyElement(const Size(60, 60)));
    expect(c[1].left, c[0].right);
    expect(c[2].top, c[0].bottom);
  });

  testWidgets('one cover fills the square and none shows the placeholder', (
    tester,
  ) async {
    await pump(tester, writeCovers(1));
    expect(find.byType(CoverArt), findsOneWidget);
    expect(tester.getSize(find.byType(CoverArt)), const Size(120, 120));

    await pump(tester, const []);
    expect(find.byType(CoverArt), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('covers off shows one placeholder whatever the keys', (
    tester,
  ) async {
    await pump(tester, [_keyOf('aa'), _keyOf('bb')], coversOn: false);

    expect(find.byType(CoverArt), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('tiles decode at their largest side and crop to fit', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pump(tester, writeCovers(3), size: 200);

    final widths = [
      for (final i in tester.widgetList<Image>(find.byType(Image)))
        (i.image as ResizeImage).width,
    ];
    // Left half is 100x200 (side 200 -> 400 px), quarters 100x100 (200 px).
    expect(widths, [
      coverDecodeWidth(400),
      coverDecodeWidth(200),
      coverDecodeWidth(200),
    ]);
    expect(tester.getSize(find.byType(PlaylistCover)), const Size(200, 200));
    expect(find.byType(ClipRRect), findsWidgets);
  });

  testWidgets('odd sizes leave no seam between cells', (tester) async {
    for (final size in [57.0, 57.5]) {
      for (final count in [2, 3, 4]) {
        await pump(tester, writeCovers(count), size: size);

        final c = cells(tester);
        expect(c, hasLength(count), reason: '$count covers at $size');
        final whole = tester.getRect(find.byType(PlaylistCover));
        expect(whole.size, Size(size, size));
        expect(c[1].left, c[0].right, reason: '$count covers at $size');
        final union = c.skip(1).fold(c.first, (a, b) => a.expandToInclude(b));
        expect(union.size, Size(size, size), reason: '$count covers at $size');
      }
    }
  });
}
