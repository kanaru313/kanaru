import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_album_links.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/library_route_keys.dart';

import 'album_modal_test_support.dart';

void main() {
  testWidgets('four or more artists open a page of rows, Back returns', (
    tester,
  ) async {
    final host = await pumpAlbumHost(
      tester,
      links: linksOf(artists: artistsOf(['A', 'B', 'C', 'D', 'E'])),
    );
    await openAlbumModalOf(tester);
    expect(find.text('5 artists'), findsOneWidget);
    expect(find.byIcon(AppIcons.chevronRight), findsWidgets);

    await tapAlbumRow(tester, 'Go to artist');
    expect(find.text('Artists · Al'), findsOneWidget);
    for (final n in ['A', 'B', 'C', 'D', 'E']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('Go to album'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await settleAlbumModal(tester);
    expect(find.text('Go to album'), findsOneWidget);

    await tapAlbumRow(tester, 'Go to artist');
    await tapAlbumRow(tester, 'D');
    expect(host.location, artistLocation('d'));
  });

  testWidgets('several folders: intro, rows, buttons', (tester) async {
    final host = await pumpAlbumHost(
      tester,
      links: linksOf(
        folders: const [
          AlbumFolder(
            path: '/m/Rock/Disc 1',
            songCount: 5,
            samplePath: '/m/Rock/Disc 1/a.flac',
          ),
          AlbumFolder(
            path: '/m/Pop',
            songCount: 2,
            samplePath: '/m/Pop/b.flac',
          ),
          AlbumFolder(
            path: '/n/Misc',
            songCount: 1,
            samplePath: '/n/Misc/c.flac',
          ),
        ],
      ),
    );
    await openAlbumModalOf(tester);
    expect(find.text('8 songs in 3 folders'), findsOneWidget);

    await tapAlbumRow(tester, 'Go to folder');
    expect(find.text('Folders · Al'), findsOneWidget);
    expect(
      find.text(
        'The songs of this album are saved in 3 folders. Pick one to open it in Folders.',
      ),
      findsOneWidget,
    );
    expect(find.text('5 songs • /m/Rock'), findsOneWidget);
    // Rows keep the order they are given: most songs first.
    final tops = [
      for (final n in ['Disc 1', 'Pop', 'Misc'])
        tester.getTopLeft(find.text(n)).dy,
    ];
    expect(tops, [...tops]..sort());
    expect(find.text('1 song • /n'), findsOneWidget);

    await tester.tap(find.byTooltip('Show in file manager').at(1));
    await settleAlbumModal(tester);
    expect(host.shownInFileManager, ['/m/Pop/b.flac']);

    await openAlbumModalOf(tester);
    await tapAlbumRow(tester, 'Go to folder');
    await tapAlbumRow(tester, 'Misc');
    expect(host.location, folderLocation('/n/Misc'));
  });

  testWidgets('no folders: the folder row is left out', (tester) async {
    await pumpAlbumHost(tester, links: linksOf(folders: const []));
    await openAlbumModalOf(tester);
    expect(find.text('Go to folder'), findsNothing);
    expect(find.text('Go to artist'), findsOneWidget);
  });

  testWidgets('a gone album greys out the link rows', (tester) async {
    await pumpAlbumHost(tester, links: null);
    await openAlbumModalOf(tester);
    expect(find.text('Go to artist'), findsOneWidget);
    await tester.tap(find.text('Go to artist'));
    await settleAlbumModal(tester);
    expect(find.text('Go to album'), findsOneWidget);
  });

  for (final page in ['artists', 'folders']) {
    testWidgets('Back from the $page page reads the links only once', (
      tester,
    ) async {
      var reads = 0;
      await pumpAlbumHost(
        tester,
        onLinksRead: () => reads++,
        links: linksOf(
          artists: artistsOf(['A', 'B', 'C', 'D']),
          folders: const [
            AlbumFolder(path: '/m/a', songCount: 2, samplePath: '/m/a/1.flac'),
            AlbumFolder(path: '/m/b', songCount: 1, samplePath: '/m/b/1.flac'),
          ],
        ),
      );
      await openAlbumModalOf(tester);
      await tapAlbumRow(
        tester,
        page == 'artists' ? 'Go to artist' : 'Go to folder',
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.tap(find.byTooltip('Back'));
      await settleAlbumModal(tester);

      expect(reads, 1);
      expect(find.text('4 artists'), findsOneWidget);
      expect(find.text('3 songs in 2 folders'), findsOneWidget);
    });
  }
}
