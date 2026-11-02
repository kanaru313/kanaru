import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/album_links_provider.dart';
import 'package:kanaru/core/database/library_browse_album_links.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:material_ui/material_ui.dart';

import 'album_modal_test_support.dart';

/// True when the primary focus sits inside the open album modal, or inside
/// [within] when given.
bool _focusInModal({Finder? within}) {
  final focus = FocusManager.instance.primaryFocus;
  if (focus is FocusScopeNode) return false;
  final ctx = focus?.context;
  if (ctx == null) return false;
  return find
      .descendant(
        of: within ?? find.bySemanticsLabel('Album options').first,
        matching: find.byElementPredicate((e) => e == ctx),
      )
      .evaluate()
      .isNotEmpty;
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('the Menu key focuses the first row; Enter acts', (tester) async {
    final host = await pumpAlbumHost(tester, links: linksOf());
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settleModal(tester);
    expect(_focusInModal(within: albumModalAction('album')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleModal(tester);
    expect(host.location, albumLocation(testAlbumKey));
  });

  testWidgets('on the album page the first row is Go to artist', (
    tester,
  ) async {
    final host = await pumpAlbumHost(
      tester,
      links: linksOf(),
      showAlbum: false,
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settleModal(tester);
    expect(_focusInModal(within: albumModalAction('artist')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleModal(tester);
    expect(host.location, artistLocation('ann'));
  });

  testWidgets(
    'links found gone while Play all has focus: Down lands on the first '
    'enabled row',
    (tester) async {
      final gate = Completer<AlbumLinks?>();
      final container = ProviderContainer(
        overrides: [
          albumModalLinksProvider(testAlbumKey)
              .overrideWith((_) => gate.future),
        ],
      );
      addTearDown(container.dispose);
      await pumpAlbumHost(tester, container: container, showAlbum: false);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await settleModal(tester);
      expect(_focusInModal(within: albumModalAction('play-all')), isTrue);

      gate.complete(null);
      await settleModal(tester);
      expect(_focusInModal(within: albumModalAction('play-all')), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(_focusInModal(within: albumModalAction('advanced')), isTrue);
    },
  );

  testWidgets('Esc closes the modal and focus returns to the tile', (
    tester,
  ) async {
    await pumpAlbumHost(tester, links: linksOf());
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settleModal(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleModal(tester);

    expect(find.text('Go to album'), findsNothing);
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
    await pumpAlbumHost(tester, links: linksOf());
    await tester.tap(find.text('tile'), buttons: kSecondaryButton);
    await settleModal(tester);
    expect(_focusInModal(), isFalse);
  });

  testWidgets('Enter on the focused more button focuses the first row', (
    tester,
  ) async {
    await pumpAlbumHost(tester, links: linksOf(), withMoreButton: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleModal(tester);
    expect(_focusInModal(within: albumModalAction('album')), isTrue);
  });

  testWidgets('a click on the more button opens with no focus in the modal', (
    tester,
  ) async {
    await pumpAlbumHost(tester, links: linksOf(), withMoreButton: true);
    await tester.tap(find.byTooltip('More options'));
    await settleModal(tester);
    expect(find.text('Go to album'), findsOneWidget);
    expect(_focusInModal(), isFalse);
  });
}
