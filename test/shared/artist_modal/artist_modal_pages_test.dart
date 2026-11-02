import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_album_links.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/album_artwork.dart';
import 'package:material_ui/material_ui.dart';

import 'artist_modal_test_support.dart';

const _folders = [
  AlbumFolder(
    path: '/m/Rock/Disc 1',
    songCount: 5,
    samplePath: '/m/Rock/Disc 1/a.flac',
  ),
  AlbumFolder(path: '/m/Pop', songCount: 2, samplePath: '/m/Pop/b.flac'),
  AlbumFolder(path: '/n/Misc', songCount: 1, samplePath: '/n/Misc/c.flac'),
];

void main() {
  testWidgets('five albums (3 + 2): a page with both headings, covers', (
    tester,
  ) async {
    final host = await pumpArtistHost(
      tester,
      links: linksOf(own: ownAlbums(3), appearsOn: otherAlbums(2)),
    );
    await openArtistModalOf(tester);
    expect(find.text('3 albums • appears on 2'), findsOneWidget);
    expect(find.byIcon(AppIcons.chevronRight), findsWidgets);

    await tapArtistRow(tester, 'Go to album');
    expect(find.text('Albums · Ann'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Appears on'), findsOneWidget);
    expect(find.text('Go to artist'), findsNothing);
    for (final a in [...ownAlbums(3), ...otherAlbums(2)]) {
      expect(find.text(a.title), findsOneWidget);
    }
    expect(find.text('2000 • 4 songs'), findsOneWidget);
    expect(find.text('4 songs'), findsNWidgets(2));
    final cover = tester.getSize(find.byType(AlbumArtwork).first);
    expect(cover, const Size(40, 40));
    // Ids count across both groups.
    expect(artistModalAction('album-0'), findsOneWidget);
    expect(artistModalAction('album-3'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Albums')).dy,
      lessThan(tester.getTopLeft(find.text('Own 0')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Appears on')).dy,
      greaterThan(tester.getTopLeft(find.text('Own 2')).dy),
    );

    await tapArtistRow(tester, 'Other 1');
    expect(host.location, artistAlbumLocation('ann', otherAlbums(2)[1].key));
  });

  testWidgets('appears-on only: no Albums heading', (tester) async {
    await pumpArtistHost(
      tester,
      links: linksOf(own: [], appearsOn: otherAlbums(5)),
    );
    await openArtistModalOf(tester);
    await tapArtistRow(tester, 'Go to album');
    expect(find.text('Albums'), findsNothing);
    expect(find.text('Appears on'), findsOneWidget);
    expect(artistModalAction('album-0'), findsOneWidget);
  });

  testWidgets('own only: no Appears on heading; Back returns', (tester) async {
    await pumpArtistHost(tester, links: linksOf(own: ownAlbums(5)));
    await openArtistModalOf(tester);
    await tapArtistRow(tester, 'Go to album');
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Appears on'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await settleModal(tester);
    expect(find.text('Go to artist'), findsOneWidget);
  });

  testWidgets('the Albums page title uses the name once loaded', (
    tester,
  ) async {
    await pumpArtistHost(
      tester,
      links: linksOf(own: ownAlbums(5), name: 'Sơn Tùng'),
    );
    await openArtistModalOf(tester);
    await tapArtistRow(tester, 'Go to album');
    expect(find.text('Albums · Sơn Tùng'), findsOneWidget);
  });

  testWidgets('three folders: intro, rows in order, buttons', (tester) async {
    final host = await pumpArtistHost(
      tester,
      links: linksOf(folders: _folders),
    );
    await openArtistModalOf(tester);
    expect(find.text('8 songs in 3 folders'), findsOneWidget);

    await tapArtistRow(tester, 'Go to folder');
    expect(find.text('Folders · Ann'), findsOneWidget);
    expect(
      find.text(
        'The songs of this artist are saved in 3 folders. Pick one to open it in Folders.',
      ),
      findsOneWidget,
    );
    expect(find.text('5 songs • /m/Rock'), findsOneWidget);
    final tops = [
      for (final n in ['Disc 1', 'Pop', 'Misc'])
        tester.getTopLeft(find.text(n)).dy,
    ];
    expect(tops, [...tops]..sort());

    await tester.tap(find.byTooltip('Show in file manager').at(1));
    await settleModal(tester);
    expect(host.shownInFileManager, ['/m/Pop/b.flac']);

    await openArtistModalOf(tester);
    await tapArtistRow(tester, 'Go to folder');
    await tapArtistRow(tester, 'Misc');
    expect(host.location, folderLocation('/n/Misc'));
  });

  testWidgets('no folders: the folder row is left out', (tester) async {
    await pumpArtistHost(tester, links: linksOf(folders: const []));
    await openArtistModalOf(tester);
    expect(find.text('Go to folder'), findsNothing);
    expect(find.text('Go to album'), findsOneWidget);
  });

  for (final page in ['albums', 'folders', 'advanced']) {
    testWidgets('Back from the $page page after scrolling reads only once', (
      tester,
    ) async {
      var reads = 0;
      await pumpArtistHost(
        tester,
        onLinksRead: () => reads++,
        links: linksOf(
          own: ownAlbums(40),
          folders: [
            for (var i = 0; i < 40; i++)
              AlbumFolder(
                path: '/m/f$i',
                songCount: 1,
                samplePath: '/m/f$i/1.flac',
              ),
          ],
        ),
      );
      await openArtistModalOf(tester);
      await tapArtistRow(tester, switch (page) {
        'albums' => 'Go to album',
        'folders' => 'Go to folder',
        _ => 'Advanced',
      });
      // Scroll to the end, where body rows are disposed.
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -20000));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.tap(find.byTooltip('Back'));
      await settleModal(tester);

      expect(reads, 1);
      expect(find.text('40 albums'), findsOneWidget);
      expect(find.text('40 songs in 40 folders'), findsOneWidget);
    });
  }
}
