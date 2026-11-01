import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_chips.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_dialog_frame.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_sheet_frame.dart';
import 'package:material_ui/material_ui.dart';

import 'artist_modal_test_support.dart';

/// Height of the Material of the open frame (dialog or sheet).
double _frameHeight(WidgetTester tester, {required bool sheet}) {
  final material = find.descendant(
    of: find.byType(sheet ? ContextModalSheetFrame : ContextModalDialogFrame),
    matching: find.byType(Material),
  );
  return tester.getSize(material.first).height;
}

void main() {
  // Composition only: the framework caps are tested with the framework.
  for (final scale in [1.0, 2.0]) {
    for (final (name, size, sheet, cap) in [
      ('dialog', const Size(1000, 480), false, 480.0 - 48),
      ('sheet', const Size(480, 720), true, 720 * 0.85),
    ]) {
      testWidgets('root in a $name at text scale $scale stays in its cap', (
        tester,
      ) async {
        await pumpArtistHost(
          tester,
          links: linksOf(own: ownAlbums(3)),
          size: size,
          textScale: scale,
        );
        await openArtistModalOf(tester);
        expect(tester.takeException(), isNull);
        expect(_frameHeight(tester, sheet: sheet), lessThanOrEqualTo(cap));

        // The last row may be below the frame: it scrolls into view.
        final advanced = find.text('Advanced');
        await tester.scrollUntilVisible(
          advanced,
          80,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(advanced, findsOneWidget);
      });
    }
  }

  testWidgets('a 40-album page in a 1000x720 dialog stays within 640', (
    tester,
  ) async {
    await pumpArtistHost(
      tester,
      links: linksOf(own: ownAlbums(40)),
      size: const Size(1000, 720),
    );
    await openArtistModalOf(tester);
    await tapArtistRow(tester, 'Go to album');
    expect(tester.takeException(), isNull);
    expect(_frameHeight(tester, sheet: false), lessThanOrEqualTo(640));

    final last = find.text('Own 39');
    await tester.scrollUntilVisible(
      last,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(last, findsOneWidget);
  });

  testWidgets('three long album titles wrap inside 400 px, chips stay small', (
    tester,
  ) async {
    final long = [for (var i = 0; i < 3; i++) albumOf('Album $i ${'x' * 74}')];
    await pumpArtistHost(
      tester,
      links: linksOf(own: long),
      size: const Size(400, 800),
    );
    await openArtistModalOf(tester);
    expect(tester.takeException(), isNull);

    final chips = find.byType(ContextModalChipsRow);
    expect(chips, findsOneWidget);
    final box = tester.getSize(chips);
    expect(box.width, lessThanOrEqualTo(400));
    expect(box.height, lessThanOrEqualTo(116));
  });
}
