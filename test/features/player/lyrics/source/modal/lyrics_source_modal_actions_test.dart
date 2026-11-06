import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('all off: Find row opens Lyrics sources', (tester) async {
    final h = await pumpSourceModal(
      tester,
      none,
      records: [modalRecord('plugin-a', 'A')],
      disabled: {'plugin-a'},
    );
    expect(
      find.text('All online sources are off · manage them in Lyrics sources'),
      findsOneWidget,
    );
    await tester.tap(find.text('Find lyrics online…'));
    await tester.pumpAndSettle();
    expect(h.location, lyricsSourcesRoute);
  });

  testWidgets('Save row closes the stack and runs the save flow', (
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
    await tester.pumpAndSettle();
    expect(find.text('Lyrics for this song'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(h.log, ['save 1']);
    expect(
      find.descendant(
        of: find.byKey(openerScaffold),
        matching: find.text('Lyrics saved as a .lrc file'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('no Save row for the file lyrics', (tester) async {
    await pumpSourceModal(
      tester,
      fakeResolution(LyricsFound(modalUri, modalLyrics()), hasLocal: true),
    );
    expect(find.text('Save lyrics…'), findsNothing);
  });
}
