import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/playing_track_original_cover.dart';
import 'package:kanaru/features/player/original_cover_layer.dart';
import 'package:kanaru/features/player/track_artwork.dart';
import 'package:material_ui/material_ui.dart';

/// A 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// A fresh copy: images made from it are different cache entries.
OriginalCover _cover(String uri, [List<int>? bytes]) =>
    (uri: uri, bytes: Uint8List.fromList(bytes ?? _png));

void main() {
  late Directory dir;
  late File thumbnail;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kanaru_original_art_test');
    thumbnail = File('${dir.path}/thumb.png')..writeAsBytesSync(_png);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pump(
    WidgetTester tester, {
    String? artUri,
    OriginalCover? original,
    bool layered = true,
    double size = 100,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: TrackArtwork(
          artUri: artUri ?? thumbnail.path,
          size: size,
          layered: layered,
          original: original,
        ),
      ),
    ),
  );

  /// Lets images decode, which happens outside the fake-async zone.
  Future<void> decode(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }

  final thumbnailImage = find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is ResizeImage &&
        (w.image as ResizeImage).imageProvider is FileImage,
  );
  final originalPixels = find.descendant(
    of: find.byType(OriginalCoverLayer),
    matching: find.byType(RawImage),
  );

  Future<Object> keyOf(WidgetTester tester) async {
    final layer = find.descendant(
      of: find.byType(OriginalCoverLayer),
      matching: find.byType(Image),
    );
    final provider = tester.widget<Image>(layer).image;
    return (await tester.runAsync(
      () => provider.obtainKey(ImageConfiguration.empty),
    ))!;
  }

  bool cached(Object key) =>
      PaintingBinding.instance.imageCache.statusForKey(key).tracked;

  testWidgets('shows the thumbnail, then the original over it', (tester) async {
    await pump(tester, original: _cover('/a'));

    expect(thumbnailImage, findsOneWidget);
    expect(originalPixels, findsNothing, reason: 'not decoded yet');

    await decode(tester);

    expect(thumbnailImage, findsOneWidget);
    expect(originalPixels, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OriginalCoverLayer),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == Colors.black,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('original bytes that do not decode leave the thumbnail', (
    tester,
  ) async {
    await pump(tester, original: _cover('/a', [1, 2, 3]));
    await decode(tester);

    expect(tester.takeException(), isNull);
    expect(thumbnailImage, findsOneWidget);
    expect(originalPixels, findsNothing);
  });

  testWidgets('another track shows none of the previous original', (
    tester,
  ) async {
    await pump(tester, original: _cover('/a'));
    await decode(tester);
    expect(originalPixels, findsOneWidget);
    final state = tester.state(thumbnailImage);

    await pump(tester, original: _cover('/b'));

    expect(originalPixels, findsNothing, reason: 'b is not decoded yet');
    expect(tester.state(thumbnailImage), same(state));
  });

  testWidgets('losing the original keeps the thumbnail image in place', (
    tester,
  ) async {
    await pump(tester, original: _cover('/a'));
    await decode(tester);
    final state = tester.state(thumbnailImage);

    // The next track: its thumbnail, and no original yet.
    final next = File('${dir.path}/next.png')..writeAsBytesSync(_png);
    await pump(tester, artUri: next.path);

    expect(find.byType(OriginalCoverLayer), findsNothing);
    expect(tester.state(thumbnailImage), same(state));
  });

  testWidgets('a resize keeps the original shown while it decodes again', (
    tester,
  ) async {
    final cover = _cover('/a');
    await pump(tester, original: cover);
    await decode(tester);
    expect(originalPixels, findsOneWidget);

    // A larger decode width: a new image, not decoded yet.
    final small = await keyOf(tester);
    await pump(tester, original: cover, size: 300);

    expect(originalPixels, findsOneWidget, reason: 'the last frame stays');
    await decode(tester);
    expect(cached(small), isFalse, reason: 'replaced');
    expect(cached(await keyOf(tester)), isTrue);
  });

  testWidgets('new bytes of the same track keep the original shown', (
    tester,
  ) async {
    await pump(tester, original: _cover('/a'));
    await decode(tester);

    // A rescan replaced the cover of the playing track.
    await pump(tester, original: _cover('/a'));

    expect(originalPixels, findsOneWidget, reason: 'the last frame stays');
  });

  testWidgets('the original cover leaves the image cache with its layer', (
    tester,
  ) async {
    await pump(tester, original: _cover('/a'));
    await decode(tester);
    final first = await keyOf(tester);
    expect(cached(first), isTrue);

    await pump(tester, original: _cover('/b'));
    await decode(tester);
    final second = await keyOf(tester);
    expect(cached(first), isFalse, reason: 'replaced');
    expect(cached(second), isTrue);

    await pump(tester, layered: false);
    await tester.pump();
    expect(cached(second), isFalse, reason: 'disposed');
  });

  testWidgets('a track without a thumbnail shows a note, then the original', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: TrackArtwork(
            artUri: null,
            size: 100,
            layered: true,
            original: _cover('/a'),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);

    await decode(tester);

    expect(originalPixels, findsOneWidget);
  });

  testWidgets('an unlayered artwork has no original layer', (tester) async {
    await pump(tester, layered: false);

    expect(find.byType(OriginalCoverLayer), findsNothing);
    expect(find.byType(Stack), findsNothing);
  });
}
