import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/features/library/albums/album_header.dart';
import 'package:kanaru/features/library/albums/album_side_pane.dart';
import 'package:kanaru/shared/album_modal/album_more_button.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/album_modal/album_modal_test_support.dart';
import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _album = [
  TestTrack('One', artist: 'Ann', album: 'Al', track: 1),
  TestTrack('Two', artist: 'Ann', album: 'Al', track: 2),
];

final _location = albumLocation(const AlbumKey('ann', 'al'));

List<String> _queueTitles(LibraryHarness h) => [
  for (final t in h.container.read(playerServiceProvider).queue.original)
    t.title,
];

Future<LibraryHarness> _open(WidgetTester tester, {required bool wide}) async {
  final h = LibraryHarness();
  await openWithTracks(tester, h, _album, location: _location);
  if (!wide) {
    tester.view.physicalSize = const Size(700, 800);
    await tester.pumpAndSettle();
  }
  return h;
}

void main() {
  for (final wide in [true, false]) {
    final layout = wide ? 'side pane' : 'header';
    final host = wide ? find.byType(AlbumSidePane) : find.byType(AlbumHeader);

    testWidgets('$layout: the more button opens the album modal', (
      tester,
    ) async {
      await _open(tester, wide: wide);
      expect(
        find.descendant(of: host, matching: find.byType(PopupMenuButton)),
        findsNothing,
      );

      await tester.tap(
        find.descendant(of: host, matching: find.byType(AlbumMoreButton)),
      );
      await settleModal(tester);

      expect(albumModalAction('play-all'), findsOneWidget);
      expect(albumModalAction('album'), findsNothing);
    });

    testWidgets('$layout: Play next from the modal queues the tracks', (
      tester,
    ) async {
      final h = await _open(tester, wide: wide);
      await tester.tap(
        find.descendant(of: host, matching: find.byType(AlbumMoreButton)),
      );
      await settleModal(tester);
      await tapAlbumRow(tester, 'Play next');

      expect(_queueTitles(h), ['One', 'Two']);
    });
  }

  testWidgets('Enter on the focused more button focuses the first row', (
    tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    await _open(tester, wide: true);
    final button = find.descendant(
      of: find.byType(AlbumMoreButton),
      matching: find.byType(Icon),
    );
    Focus.of(tester.element(button)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleModal(tester);

    final focus = FocusManager.instance.primaryFocus;
    expect(focus, isNot(isA<FocusScopeNode>()));
    expect(
      find
          .descendant(
            of: albumModalAction('artist'),
            matching: find.byElementPredicate((e) => e == focus?.context),
          )
          .evaluate(),
      isNotEmpty,
    );
  });
}
