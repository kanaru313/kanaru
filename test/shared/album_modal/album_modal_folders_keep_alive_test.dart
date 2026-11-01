import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_album_links.dart';

import 'album_modal_test_support.dart';

void main() {
  testWidgets('Back after scrolling a long folders page keeps the links', (
    tester,
  ) async {
    var reads = 0;
    await pumpAlbumHost(
      tester,
      size: const Size(1000, 400),
      onLinksRead: () => reads++,
      links: linksOf(
        folders: [
          for (var i = 0; i < 30; i++)
            AlbumFolder(
              path: '/m/f${i.toString().padLeft(2, '0')}',
              songCount: 1,
              samplePath: '/m/f$i/1.flac',
            ),
        ],
      ),
    );
    await openAlbumModalOf(tester);
    await tapAlbumRow(tester, 'Go to folder');

    // Scroll the page until its last row is built, so the first rows (and
    // anything at the start of the body) are long gone.
    await tester.dragUntilVisible(
      find.text('f29'),
      find.byType(Scrollable).last,
      const Offset(0, -200),
    );
    await settleAlbumModal(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    // The first frame after Back already has the enabled folder row.
    expect(albumModalAction('folders'), findsOneWidget);
    expect(find.text('30 songs in 30 folders'), findsOneWidget);
    await settleAlbumModal(tester);
    expect(reads, 1);
    expect(find.text('30 songs in 30 folders'), findsOneWidget);
  });
}
