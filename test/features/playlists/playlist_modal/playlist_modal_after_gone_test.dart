import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:material_ui/material_ui.dart' show InkWell;

import '../../library/browse_test_data.dart';
import '../../library/library_test_harness.dart';
import '../playlist_test_data.dart';
import 'playlist_modal_test_support.dart';

void main() {
  late LibraryHarness h;
  setUp(() => h = LibraryHarness());

  testWidgets('a playlist deleted while open keeps the snapshot header', (
    tester,
  ) async {
    await insertTracks(tester, h, const [TestTrack('a'), TestTrack('b')]);
    final id = await seedPlaylist(tester, h, 'Mix', ['a', 'b']);
    await pumpModalHost(tester, h, id: id);
    await openPlaylistModalOf(tester);

    await tester.runAsync(() => h.db.deletePlaylist(id));
    await settleModal(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Mix'), findsWidgets);
    expect(find.textContaining('2 songs • Created'), findsOneWidget);
    for (final row in [
      'play-all',
      'shuffle',
      'edit',
      'delete',
      'go-to-playlist',
    ]) {
      await tester.tap(modalAction(row));
      await settleModal(tester);
      expect(modalAction(row), findsOneWidget, reason: '$row does nothing');
    }
    final next = find.byKey(const ValueKey('playlist-modal-play-next'));
    expect(tester.widget<InkWell>(next).onTap, isNull);
    expect(queueTitles(h), isEmpty);
  });

  testWidgets('the opener going away does not break the open modal', (
    tester,
  ) async {
    await insertTracks(tester, h, const [TestTrack('a'), TestTrack('b')]);
    final id = await seedPlaylist(tester, h, 'Mix', ['a', 'b']);
    final host = await pumpModalHost(tester, h, id: id);
    await openPlaylistModalOf(tester);

    host.shown.value = false;
    await settleModal(tester);
    await tapModalAction(tester, 'go-to-playlist');

    expect(tester.takeException(), isNull);
    expect(host.location, '/playlists/$id');
  });
}
