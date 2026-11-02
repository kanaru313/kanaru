import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/album_links_provider.dart';
import 'package:kanaru/core/database/library_browse_album_links.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import 'album_modal_test_support.dart';

/// Whether the row [id] of the open modal answers a tap.
bool _rowEnabled(WidgetTester tester, String id) =>
    tester
        .widget<InkWell>(
          find
              .descendant(
                of: albumModalAction(id),
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap !=
    null;

/// Whether the footer button [suffix] (`play-next`, `add-to-queue`) answers.
bool _footerEnabled(WidgetTester tester, String suffix) =>
    tester.widget<InkWell>(find.byKey(ValueKey('album-modal-$suffix'))).onTap !=
    null;

const _actionRows = ['play-all', 'shuffle', 'add-to-playlist'];
const _footer = ['play-next', 'add-to-queue'];

/// Checks the five acting rows and the footer all answer as [enabled]; opens
/// the Advanced page for Add all to Favorites.
Future<void> _expectActing(WidgetTester tester, {required bool enabled}) async {
  for (final id in _actionRows) {
    expect(_rowEnabled(tester, id), enabled, reason: id);
  }
  for (final b in _footer) {
    expect(_footerEnabled(tester, b), enabled, reason: b);
  }
  await tapAlbumRow(tester, 'Advanced');
  expect(_rowEnabled(tester, 'add-all-to-favorites'), enabled);
}

void main() {
  testWidgets('a gone album greys out the play rows and the footer', (
    tester,
  ) async {
    final host = await pumpAlbumHost(tester, links: null);
    await openAlbumModalOf(tester);
    await _expectActing(tester, enabled: false);

    // Back on the first page, a tap on the footer neither closes nor queues.
    await tester.tap(find.byTooltip('Back'));
    await settleModal(tester);
    await tester.tap(find.byKey(const ValueKey('album-modal-play-next')));
    await settleModal(tester);
    expect(albumModalAction('play-all'), findsOneWidget);
    expect(host.queueActions, isEmpty);
  });

  testWidgets('while the links load the play rows and footer stay enabled', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        albumModalLinksProvider(testAlbumKey)
            .overrideWith((ref) => Completer<AlbumLinks?>().future),
      ],
    );
    addTearDown(container.dispose);
    await pumpAlbumHost(tester, container: container);
    await openAlbumModalOf(tester);
    expect(_rowEnabled(tester, 'artist'), isFalse, reason: 'still loading');
    await _expectActing(tester, enabled: true);
  });

  testWidgets('with links the play rows and footer are enabled', (
    tester,
  ) async {
    final host = await pumpAlbumHost(tester, links: linksOf());
    await openAlbumModalOf(tester);
    await tester.tap(find.byKey(const ValueKey('album-modal-add-to-queue')));
    await settleModal(tester);
    expect(host.queueActions, [QueueAction.addToQueue]);

    await openAlbumModalOf(tester);
    await _expectActing(tester, enabled: true);
  });
}
