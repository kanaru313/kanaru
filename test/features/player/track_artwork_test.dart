import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/player/track_artwork.dart';
import 'package:material_ui/material_ui.dart';

/// A 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('kanaru_art_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester, String? artUri) => tester.pumpWidget(
    MaterialApp(
      home: Center(child: TrackArtwork(artUri: artUri, size: 100)),
    ),
  );

  FileImage fileImage(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image)).image;
    return (image as ResizeImage).imageProvider as FileImage;
  }

  testWidgets('shows a music note without art', (tester) async {
    await pump(tester, null);

    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.getSize(find.byType(TrackArtwork)), const Size(100, 100));
  });

  testWidgets('shows a music note for art that is not a local file', (
    tester,
  ) async {
    await pump(tester, 'https://example.com/cover.jpg');

    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('loads a plain path', (tester) async {
    final file = File('${dir.path}/cover.png')..writeAsBytesSync(_png);
    await pump(tester, file.path);

    expect(fileImage(tester).file.path, file.path);
  });

  testWidgets('loads a file URI, decoding escapes', (tester) async {
    final file = File('${dir.path}/my cover.png')..writeAsBytesSync(_png);
    await pump(tester, file.uri.toString());

    expect(fileImage(tester).file.path, file.path);
  });

  testWidgets('decodes no larger than shown', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final file = File('${dir.path}/cover.png')..writeAsBytesSync(_png);
    await pump(tester, file.path);

    final image = tester.widget<Image>(find.byType(Image)).image;
    expect((image as ResizeImage).width, 200);
  });

  testWidgets('falls back to the music note when the file is missing', (
    tester,
  ) async {
    await pump(tester, '${dir.path}/missing.png');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
  });
}
