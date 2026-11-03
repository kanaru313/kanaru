import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_sheet_frame.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import 'artist_modal_test_support.dart';

Finder get _modal => find.bySemanticsLabel('Artist options').first;

void main() {
  testWidgets('opens named Artist options with the rows, no divider', (
    tester,
  ) async {
    await pumpArtistHost(tester, links: linksOf());
    await openArtistModalOf(tester);

    expect(find.bySemanticsLabel('Artist options'), findsWidgets);
    for (final label in [
      'Go to artist',
      'Go to album',
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

  testWidgets('Go to artist is left out on the artist page', (tester) async {
    await pumpArtistHost(tester, links: linksOf(), showArtist: false);
    await openArtistModalOf(tester);
    expect(find.text('Go to artist'), findsNothing);
    expect(find.text('Go to album'), findsOneWidget);
  });

  testWidgets('three albums: chips are open and wrapped, not a strip', (
    tester,
  ) async {
    final host = await pumpArtistHost(
      tester,
      links: linksOf(own: ownAlbums(3)),
    );
    await openArtistModalOf(tester);

    expect(find.text('3 albums'), findsWidgets);
    expect(
      find.ancestor(of: find.text('Own 2'), matching: find.byType(Wrap)),
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

    await tapArtistRow(tester, 'Own 2');
    expect(host.location, artistAlbumLocation('ann', ownAlbums(3)[2].key));
    expect(find.text('Own 2'), findsNothing);
  });

  testWidgets('one album, the folder and the artist go to their pages', (
    tester,
  ) async {
    final host = await pumpArtistHost(tester, links: linksOf());

    await openArtistModalOf(tester);
    await tapArtistRow(tester, 'Go to artist');
    expect(host.location, artistLocation('ann'));

    host.router.go('/');
    await settleModal(tester);
    await openArtistModalOf(tester);
    await tapArtistRow(tester, 'Go to folder');
    expect(host.location, folderLocation('/m/Rock'));

    host.router.go('/');
    await settleModal(tester);
    await openArtistModalOf(tester);
    await tapArtistRow(tester, 'Go to album');
    expect(host.location, artistAlbumLocation('ann', ownAlbums(1).single.key));
  });

  testWidgets('tapping the header goes to the artist', (tester) async {
    final host = await pumpArtistHost(tester, links: linksOf());
    await openArtistModalOf(tester);
    await tester.tap(find.text('3 albums • 12 songs • 1 h 0 min'));
    await settleModal(tester);
    expect(host.location, artistLocation('ann'));
    expect(find.text('Go to artist'), findsNothing);
  });

  testWidgets('the header names the artist as the page does once loaded', (
    tester,
  ) async {
    await pumpArtistHost(tester, links: linksOf(name: 'Sơn Tùng'));
    await openArtistModalOf(tester);
    expect(find.text('Sơn Tùng'), findsWidgets);
  });

  testWidgets('the header is not tappable on the artist page', (tester) async {
    await pumpArtistHost(tester, links: linksOf(), showArtist: false);
    await openArtistModalOf(tester);
    expect(
      find.ancestor(
        of: find.text('3 albums • 12 songs • 1 h 0 min'),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('the folder button shows the sample file in the file manager', (
    tester,
  ) async {
    final host = await pumpArtistHost(tester, links: linksOf());
    await openArtistModalOf(tester);

    await tester.tap(find.byTooltip('Show in file manager'));
    await settleModal(tester);

    expect(host.shownInFileManager, ['/m/Rock/1.flac']);
    expect(find.text('Go to folder'), findsNothing);
  });

  testWidgets('Advanced: favorites and coming soon rows', (tester) async {
    await pumpArtistHost(tester, links: linksOf());
    await openArtistModalOf(tester);

    await tapArtistRow(tester, 'Advanced');
    expect(find.text('Add all to Favorites'), findsOneWidget);
    expect(find.text('12 songs'), findsNothing);
    expect(find.text('Show in file manager'), findsNothing);
    expect(find.text('Split or merge artist'), findsOneWidget);
    expect(find.text('Delete files'), findsOneWidget);
    expect(find.text('12 files'), findsOneWidget);
    expect(find.text('Keeps the files'), findsOneWidget);
    expect(find.text('Go to artist'), findsNothing);

    await tapArtistRow(tester, 'Split or merge artist');
    expect(find.textContaining("isn't available yet"), findsOneWidget);
  });

  testWidgets('Advanced without a local folder keeps Add all to Favorites', (
    tester,
  ) async {
    await pumpArtistHost(tester, links: linksOf(folders: const []));
    await openArtistModalOf(tester);
    await tapArtistRow(tester, 'Advanced');
    expect(find.text('Show in file manager'), findsNothing);
    expect(find.text('Add all to Favorites'), findsOneWidget);
  });

  testWidgets('Esc on a page goes back, on the root closes', (tester) async {
    await pumpArtistHost(tester, links: linksOf());
    await openArtistModalOf(tester);
    await tapArtistRow(tester, 'Advanced');

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
    await pumpArtistHost(
      tester,
      links: linksOf(own: ownAlbums(3)),
      size: const Size(400, 800),
    );
    await openArtistModalOf(tester);

    expect(find.byType(ContextModalSheetFrame), findsOneWidget);
    expect(find.text('Go to artist'), findsOneWidget);
    expect(find.text('Own 2'), findsOneWidget);
    expect(
      find.descendant(of: _modal, matching: find.byType(Divider)),
      findsNothing,
    );
  });

  testWidgets('a gone artist greys out the album row', (tester) async {
    await pumpArtistHost(tester, links: null);
    await openArtistModalOf(tester);
    expect(find.text('Go to album'), findsOneWidget);
    await tester.tap(find.text('Go to album'));
    await settleModal(tester);
    expect(find.text('Go to artist'), findsOneWidget);
  });

  testWidgets('queue buttons run the caller\'s action', (tester) async {
    final host = await pumpArtistHost(tester, links: linksOf());
    await openArtistModalOf(tester);
    await tapArtistRow(tester, 'Play next');
    await openArtistModalOf(tester);
    await tapArtistRow(tester, 'Add to playlist…');
    expect(host.queueActions, [
      QueueAction.playNext,
      QueueAction.addToPlaylist,
    ]);
  });
}
