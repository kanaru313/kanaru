import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/track_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import 'song_modal_test_support.dart';

const _song = TrackListItem(id: 1, path: '/m/1.flac', title: 'one');

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

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TrackActionsRegion(
            song: _song,
            onQueueAction: (_) {},
            child: const Focus(
              autofocus: true,
              child: SizedBox(width: 300, height: 80, child: Text('row')),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('the Menu key opens with focus inside the modal', (tester) async {
    await _pump(tester);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settleSongModal(tester);
    expect(find.text('Go to artist'), findsOneWidget);
    expect(_focusInModal(), isTrue);
  });

  testWidgets('a right click opens with no focus inside the modal', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('row'), buttons: kSecondaryButton);
    await settleSongModal(tester);
    expect(find.text('Go to artist'), findsOneWidget);
    expect(_focusInModal(), isFalse);
  });

  testWidgets('a mouse click into Advanced focuses no row', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('row'), buttons: kSecondaryButton);
    await settleSongModal(tester);
    await tapModalAction(tester, 'Advanced');
    expect(_focusInModal(), isFalse);
  });
}
