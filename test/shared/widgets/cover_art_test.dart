import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/cover_art.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kanaru_cover_test');
    PaintingBinding.instance.imageCache.clear();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  const placeholder = Icon(Icons.album);

  Future<void> pump(WidgetTester tester, String? path, {double size = 100}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: CoverArt(path: path, size: size, placeholder: placeholder),
          ),
        ),
      );

  ResizeImage resized(WidgetTester tester) =>
      tester.widget<Image>(find.byType(Image)).image as ResizeImage;

  test('decode widths go up in fixed steps and stop at 512', () {
    expect(coverDecodeWidth(1), 64);
    expect(coverDecodeWidth(64), 64);
    expect(coverDecodeWidth(65), 128);
    expect(coverDecodeWidth(200), 256);
    expect(coverDecodeWidth(257), 512);
    expect(coverDecodeWidth(4000), 512);
  });

  testWidgets('shows the placeholder without a path', (tester) async {
    await pump(tester, null);

    expect(find.byIcon(Icons.album), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.getSize(find.byType(CoverArt)), const Size(100, 100));
  });

  testWidgets('loads the file at its size, decoded in steps', (tester) async {
    final path = '${dir.path}/ab/cover.jpg';
    for (final (size, dpr, width) in [
      (100.0, 1.0, 128),
      (48.0, 2.0, 128),
      (160.0, 2.0, 512),
      (400.0, 2.0, 512),
    ]) {
      tester.view.devicePixelRatio = dpr;
      await pump(tester, path, size: size);

      final image = resized(tester);
      expect((image.imageProvider as FileImage).file.path, path);
      expect(image.width, width, reason: 'size $size at dpr $dpr');
      expect(tester.getSize(find.byType(CoverArt)), Size(size, size));
    }
    tester.view.reset();
  });

  testWidgets('falls back to the placeholder when the file is missing', (
    tester,
  ) async {
    await pump(tester, '${dir.path}/missing.jpg');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(find.byIcon(Icons.album), findsOneWidget);
  });

  testWidgets('falls back to the placeholder for an empty file', (
    tester,
  ) async {
    final empty = File('${dir.path}/empty.jpg')..writeAsBytesSync([]);
    await pump(tester, empty.path);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(find.byIcon(Icons.album), findsOneWidget);
  });
}
