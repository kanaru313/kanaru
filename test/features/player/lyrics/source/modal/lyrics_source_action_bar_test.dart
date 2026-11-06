import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_source_provider.dart';

import 'lyrics_source_modal_test_harness.dart';

void main() {
  final alpha = [modalRecord('plugin-a', 'Alpha')];
  LyricsSourceResolution found({required bool pinned}) => fakeResolution(
    LyricsFound(modalUri, modalLyrics(), origin: modalOrigin(pinned: pinned)),
  );

  testWidgets('automatic match: Keep and Not this song use the origin', (
    tester,
  ) async {
    final h = await pumpSourceModal(
      tester,
      found(pinned: false),
      records: alpha,
    );
    expect(find.text('Found automatically'), findsOneWidget);
    await tester.tap(find.text('Keep this one'));
    await tester.pumpAndSettle();
    expect(find.text('Lyrics for this song'), findsNothing);
    expect(h.log, ['keep 1']);
  });

  testWidgets('automatic match: Not this song rejects', (tester) async {
    final h = await pumpSourceModal(
      tester,
      found(pinned: false),
      records: alpha,
    );
    await tester.tap(find.text('Not the current lyrics'));
    await tester.pumpAndSettle();
    expect(h.log, ['reject 1']);
  });

  testWidgets('kept version: no Keep button', (tester) async {
    await pumpSourceModal(tester, found(pinned: true), records: alpha);
    expect(find.text('Using the kept version'), findsOneWidget);
    expect(find.text('Keep this one'), findsNothing);
    expect(find.text('Not the current lyrics'), findsOneWidget);
  });

  testWidgets('no bar for the file lyrics', (tester) async {
    await pumpSourceModal(
      tester,
      fakeResolution(LyricsFound(modalUri, modalLyrics()), hasLocal: true),
    );
    expect(find.text('Keep this one'), findsNothing);
  });
}
