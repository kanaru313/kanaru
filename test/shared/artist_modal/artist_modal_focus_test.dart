import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/artist_modal/artist_modal_links.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:material_ui/material_ui.dart';

import 'artist_modal_test_support.dart';

/// True when the primary focus sits inside the open artist modal, or inside
/// [within] when given.
bool _focusInModal({Finder? within}) {
  final focus = FocusManager.instance.primaryFocus;
  if (focus is FocusScopeNode) return false;
  final ctx = focus?.context;
  if (ctx == null) return false;
  return find
      .descendant(
        of: within ?? find.bySemanticsLabel('Artist options').first,
        matching: find.byElementPredicate((e) => e == ctx),
      )
      .evaluate()
      .isNotEmpty;
}

Future<void> _openWithMenuKey(WidgetTester tester) async {
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
  await settleArtistModal(tester);
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets(
    'the Menu key focuses the first row, not the header; Enter acts',
    (tester) async {
      final host = await pumpArtistHost(tester, links: linksOf());
      await _openWithMenuKey(tester);
      expect(_focusInModal(within: artistModalAction('artist')), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleArtistModal(tester);
      expect(host.location, artistLocation('ann'));
    },
  );

  testWidgets('on the artist page, links loading: Play all is first', (
    tester,
  ) async {
    final gate = Completer<ArtistLinks?>();
    await pumpArtistHost(tester, showArtist: false, gate: gate);
    await _openWithMenuKey(tester);
    expect(_focusInModal(within: artistModalAction('play-all')), isTrue);
    gate.complete(linksOf());
  });

  testWidgets('on the artist page, links loaded: Go to album is first', (
    tester,
  ) async {
    final host = await pumpArtistHost(
      tester,
      links: linksOf(),
      showArtist: false,
    );
    await _openWithMenuKey(tester);
    expect(_focusInModal(within: artistModalAction('album')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleArtistModal(tester);
    expect(host.location, artistAlbumLocation('ann', ownAlbums(1).single.key));
  });

  testWidgets('Down through a 40-album page reaches the last row; Enter goes', (
    tester,
  ) async {
    final host = await pumpArtistHost(
      tester,
      links: linksOf(own: ownAlbums(40)),
    );
    await _openWithMenuKey(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleArtistModal(tester);
    expect(artistModalAction('album-0'), findsOneWidget);

    // A new page starts without focus; the first Down lands on its first row.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_focusInModal(within: artistModalAction('album-0')), isTrue);
    for (var i = 0; i < 39; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      // A frame per key, as a person pressing keys: rows scrolled into view
      // are built for the next press.
      await tester.pumpAndSettle();
    }
    expect(_focusInModal(within: artistModalAction('album-39')), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleArtistModal(tester);
    expect(host.location, artistAlbumLocation('ann', ownAlbums(40)[39].key));
  });

  testWidgets('Esc goes back from the Albums page, then closes', (
    tester,
  ) async {
    await pumpArtistHost(tester, links: linksOf(own: ownAlbums(5)));
    await _openWithMenuKey(tester);
    await tapArtistRow(tester, 'Go to album');
    expect(find.text('Albums · Ann'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleArtistModal(tester);
    expect(find.text('Go to artist'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleArtistModal(tester);
    expect(find.text('Go to artist'), findsNothing);
  });

  testWidgets('Esc closes the modal and focus returns to the row', (
    tester,
  ) async {
    await pumpArtistHost(tester, links: linksOf());
    await _openWithMenuKey(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleArtistModal(tester);

    expect(find.text('Go to artist'), findsNothing);
    final focus = FocusManager.instance.primaryFocus;
    expect(
      find.descendant(
        of: find.byElementPredicate((e) => e == focus?.context),
        matching: find.text('tile'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a right click opens with no focus in the modal', (tester) async {
    await pumpArtistHost(tester, links: linksOf());
    await tester.tap(find.text('tile'), buttons: kSecondaryButton);
    await settleArtistModal(tester);
    expect(_focusInModal(), isFalse);
  });

  testWidgets('Enter on the focused more button focuses the first row', (
    tester,
  ) async {
    await pumpArtistHost(tester, links: linksOf(), withMoreButton: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleArtistModal(tester);
    expect(_focusInModal(within: artistModalAction('artist')), isTrue);
  });

  testWidgets('a click on the more button opens with no focus in the modal', (
    tester,
  ) async {
    await pumpArtistHost(tester, links: linksOf(), withMoreButton: true);
    await tester.tap(find.byTooltip('More options'));
    await settleArtistModal(tester);
    expect(find.text('Go to artist'), findsOneWidget);
    expect(_focusInModal(), isFalse);
  });
}
