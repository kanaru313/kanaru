import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_sheet_frame.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import 'album_modal_test_support.dart';

Finder get _modal => find.bySemanticsLabel('Album options').first;

void main() {
  testWidgets('opens named Album options with the rows, no divider', (
    tester,
  ) async {
    await pumpAlbumHost(tester, links: linksOf());
    await openAlbumModalOf(tester);

    expect(find.bySemanticsLabel('Album options'), findsWidgets);
    for (final label in [
      'Go to album',
      'Go to artist',
      'Go to folder',
      'Play all',
      'Shuffle',
      'Edit tags',
      'Advanced',
      'Play next',
      'Add to queue',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(
      find.descendant(of: _modal, matching: find.byType(Divider)),
      findsNothing,
    );
  });

  testWidgets('Go to album is left out on the album page', (tester) async {
    await pumpAlbumHost(tester, links: linksOf(), showAlbum: false);
    await openAlbumModalOf(tester);
    expect(find.text('Go to album'), findsNothing);
    expect(find.text('Go to artist'), findsOneWidget);
  });

  testWidgets('two artists: chips are open and wrapped, not a strip', (
    tester,
  ) async {
    final host = await pumpAlbumHost(
      tester,
      links: linksOf(artists: artistsOf(['Ann', 'Bob'])),
    );
    await openAlbumModalOf(tester);

    expect(find.text('2 artists'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('Bob'), matching: find.byType(Wrap)),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: _modal,
        matching: find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.horizontal,
        ),
      ),
      findsNothing,
    );

    await tapAlbumRow(tester, 'Bob');
    expect(host.location, artistLocation('bob'));
    expect(find.text('Bob'), findsNothing);
  });

  testWidgets('one artist, the folder and the album go to their pages', (
    tester,
  ) async {
    final host = await pumpAlbumHost(tester, links: linksOf());

    await openAlbumModalOf(tester);
    await tapAlbumRow(tester, 'Go to artist');
    expect(host.location, artistLocation('ann'));

    host.router.go('/');
    await settleModal(tester);
    await openAlbumModalOf(tester);
    await tapAlbumRow(tester, 'Go to folder');
    expect(host.location, folderLocation('/m/Rock'));

    host.router.go('/');
    await settleModal(tester);
    await openAlbumModalOf(tester);
    await tapAlbumRow(tester, 'Go to album');
    expect(host.location, albumLocation(testAlbumKey));
  });

  testWidgets('the folder button shows the sample file in the file manager', (
    tester,
  ) async {
    final host = await pumpAlbumHost(tester, links: linksOf());
    await openAlbumModalOf(tester);

    await tester.tap(find.byTooltip('Show in file manager'));
    await settleModal(tester);

    expect(host.shownInFileManager, ['/m/Rock/1.flac']);
    expect(find.text('Go to folder'), findsNothing);
  });

  testWidgets('Advanced opens a page and shows actions', (tester) async {
    await pumpAlbumHost(tester, links: linksOf());
    await openAlbumModalOf(tester);

    await tapAlbumRow(tester, 'Advanced');
    expect(find.text('Add all to Favorites'), findsOneWidget);
    expect(find.text('Delete files'), findsOneWidget);
    expect(find.text('3 files'), findsOneWidget);
    expect(find.text('Keeps the files'), findsOneWidget);
    expect(find.text('Go to artist'), findsNothing);
    expect(find.text('Show in file manager'), findsNothing);
  });

  testWidgets('Advanced: Back returns, coming soon rows stay', (tester) async {
    await pumpAlbumHost(tester, links: linksOf());
    await openAlbumModalOf(tester);
    await tapAlbumRow(tester, 'Advanced');
    await tapAlbumRow(tester, 'Delete files');
    expect(find.textContaining("isn't available yet"), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await settleModal(tester);
    expect(find.text('Go to artist'), findsOneWidget);
  });

  testWidgets('Esc on a page goes back, on the root closes', (tester) async {
    await pumpAlbumHost(tester, links: linksOf());
    await openAlbumModalOf(tester);
    await tapAlbumRow(tester, 'Advanced');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleModal(tester);
    expect(find.text('Go to artist'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleModal(tester);
    expect(find.text('Go to artist'), findsNothing);
  });

  testWidgets('a narrow window opens a sheet with wrapped chips', (
    tester,
  ) async {
    await pumpAlbumHost(
      tester,
      links: linksOf(artists: artistsOf(['Ann', 'Bob', 'Cy'])),
      size: const Size(400, 800),
    );
    await openAlbumModalOf(tester);

    expect(find.byType(ContextModalSheetFrame), findsOneWidget);
    expect(find.text('Go to album'), findsOneWidget);
    expect(find.text('Cy'), findsOneWidget);
    expect(
      find.descendant(of: _modal, matching: find.byType(Divider)),
      findsNothing,
    );
  });

  testWidgets('queue buttons run the caller\'s action', (tester) async {
    final host = await pumpAlbumHost(tester, links: linksOf());
    await openAlbumModalOf(tester);
    await tapAlbumRow(tester, 'Play next');
    await openAlbumModalOf(tester);
    await tapAlbumRow(tester, 'Add to playlist…');
    expect(host.queueActions, [
      QueueAction.playNext,
      QueueAction.addToPlaylist,
    ]);
  });
}
