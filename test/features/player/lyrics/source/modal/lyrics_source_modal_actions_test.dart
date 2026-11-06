import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_dialog.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';

import 'lyrics_source_modal_test_harness.dart';

void main() {
  final none = fakeResolution(LyricsNone(modalUri, LyricsNoneReason.noLyrics));

  testWidgets('no plugin: Add row opens the store on Lyrics', (tester) async {
    final h = await pumpSourceModal(tester, none);
    expect(find.text('Find lyrics online…'), findsNothing);
    await tester.tap(find.text('Add an online lyrics source'));
    await tester.pumpAndSettle();
    expect(find.text('Lyrics for this song'), findsNothing);
    expect(h.location, '$lyricsSourcesStoreRoute?kind=lyrics');
  });

  testWidgets('plugins on: Find row counts on and off', (tester) async {
    await pumpSourceModal(
      tester,
      none,
      records: [modalRecord('plugin-a', 'A'), modalRecord('plugin-b', 'B')],
      disabled: {'plugin-b'},
    );
    expect(find.text('1 on · 1 off'), findsOneWidget);
  });

  testWidgets('all off: Find row still opens the picker', (tester) async {
    await pumpSourceModal(
      tester,
      none,
      manualConsent: true,
      records: [modalRecord('plugin-a', 'A')],
      disabled: {'plugin-a'},
    );
    expect(
      find.text('All sources are off (1) · searched only when you ask'),
      findsOneWidget,
    );
    await tester.tap(find.text('Find lyrics online…'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(LyricsPickerDialog), findsOneWidget);
    expect(find.text('Lyrics for this song'), findsOneWidget);
  });

  testWidgets('Save row opens the child modal and saving runs the flow', (
    tester,
  ) async {
    final h = await pumpSourceModal(
      tester,
      fakeResolution(
        LyricsFound(modalUri, modalLyrics(), origin: modalOrigin()),
      ),
      records: [modalRecord('plugin-a', 'Alpha')],
    );
    await tester.tap(find.text('Save lyrics…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    // The parent stays under the child modal.
    expect(find.text('Lyrics for this song'), findsOneWidget);
    expect(find.text('Save lyrics to'), findsOneWidget);
    await tester.tap(find.text('Save (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Lyrics for this song'), findsNothing);
    expect(find.text('Save lyrics to'), findsNothing);
    expect(h.log, ['save 1']);
    expect(
      find.descendant(
        of: find.byKey(openerScaffold),
        matching: find.text('Lyrics saved as a .lrc file'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tag lyrics have a Save row that writes them as .lrc', (
    tester,
  ) async {
    final h = await pumpSourceModal(
      tester,
      fakeResolution(
        LyricsFound(modalUri, modalLyrics(source: LyricsSource.embedded)),
        hasLocal: true,
      ),
    );
    await tester.tap(find.text('Save lyrics…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Save (1)'));
    await tester.pumpAndSettle();
    expect(h.log, ['saveLocal']);
  });

  testWidgets('no Save row for the file lyrics', (tester) async {
    await pumpSourceModal(
      tester,
      fakeResolution(LyricsFound(modalUri, modalLyrics()), hasLocal: true),
    );
    expect(find.text('Save lyrics…'), findsNothing);
  });
}
