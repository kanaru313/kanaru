import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/shared/song_modal/song_modal_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/song_modal/song_modal_test_support.dart';
import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import '../playlists/playlist_test_data.dart';
import 'queue_tile_menu_test_support.dart';

const _library = [
  TestTrack('a', artist: 'Ann', album: 'Al'),
  TestTrack('b', artist: 'Ann', album: 'Al'),
];

/// True when the primary focus sits inside the open song modal.
bool _focusInModal() {
  final focus = FocusManager.instance.primaryFocus;
  // The modal's own scope holds focus while no row does.
  if (focus is FocusScopeNode) return false;
  final ctx = focus?.context;
  if (ctx == null) return false;
  return find
      .descendant(
        of: find.bySemanticsLabel('Song options').first,
        matching: find.byElementPredicate((e) => e == ctx),
      )
      .evaluate()
      .isNotEmpty;
}

void main() {
  late LibraryHarness h;

  setUp(() {
    h = LibraryHarness(refreshInterval: Duration.zero);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  Future<void> open(WidgetTester tester, [List<Track> extra = const []]) async {
    await openWithTracks(tester, h, _library, location: '/home');
    final p = await trackPaths(tester, h);
    await playAndOpenQueue(tester, h, [
      Track(uri: p['a']!, title: 'a'),
      Track(uri: p['b']!, title: 'b'),
      ...extra,
    ]);
  }

  Finder moreOf(String title) => find.descendant(
    of: queueRow(title).last,
    matching: find.byTooltip('More options'),
  );

  Future<void> focusMore(WidgetTester tester, String title) async {
    // The icon sits inside the button's own focus node, below the row's.
    final icon = find.descendant(
      of: moreOf(title),
      matching: find.byType(Icon),
    );
    Focus.of(tester.element(icon)).requestFocus();
    await tester.pump();
  }

  final modal = find.byType(SongModalHeader);

  for (final (name, key) in [
    ('Enter', LogicalKeyboardKey.enter),
    ('Space', LogicalKeyboardKey.space),
  ]) {
    testWidgets('$name on the focused more button focuses the first row', (
      tester,
    ) async {
      await open(tester);
      await focusMore(tester, 'b');
      await tester.sendKeyEvent(key);
      await settleSongModal(tester);

      expect(modal, findsOneWidget);
      expect(_focusInModal(), isTrue);
    });
  }

  testWidgets('a click on the more button opens the modal with no row focus', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(moreOf('b'));
    await settleSongModal(tester);

    expect(modal, findsOneWidget);
    expect(_focusInModal(), isFalse);
  });

  testWidgets('the more button of a song outside the library opens a popup', (
    tester,
  ) async {
    await open(tester, const [Track(uri: '/nowhere/x.mp3', title: 'x')]);
    await tester.tap(moreOf('x'));
    await settleDb(tester);
    await settleSongModal(tester);

    expect(modal, findsNothing);
    expect(find.text('Remove from queue'), findsOneWidget);
    expect(find.byType(PopupMenuItem<Object>), findsWidgets);
  });

  testWidgets(
    'a long press on the more button shows the tooltip and opens no menu',
    (tester) async {
      await open(tester);
      await tester.longPress(moreOf('b'));
      await settleSongModal(tester);

      // The button's tooltip wins the press over the row's long press.
      expect(modal, findsNothing);
      expect(find.text('More options'), findsOneWidget);
    },
  );
}
