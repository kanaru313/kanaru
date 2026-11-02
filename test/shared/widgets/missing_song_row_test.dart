import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_providers.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/context_menu_region.dart';
import 'package:kanaru/shared/widgets/favorite_button.dart';
import 'package:kanaru/shared/widgets/menu_keyboard_region.dart';
import 'package:kanaru/shared/widgets/missing_song_row.dart';
import 'package:material_ui/material_ui.dart';

typedef _Call = ({bool viaKeyboard, Offset at});

const _path = '/music/gone/lost.flac';

Future<void> _pump(WidgetTester tester, Widget row) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      favoritePathsProvider.overrideWith((ref) => Stream.value(const {})),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            // Something before the row, so Tab has to move to reach it.
            TextButton(onPressed: () {}, child: const Text('before')),
            row,
          ],
        ),
      ),
    ),
  ),
);

/// The focus highlight painted over the row's card, if any.
Finder _highlight(WidgetTester tester) {
  final color = Theme.of(tester.element(find.byType(MissingSongRow)))
      .focusColor;
  return find.descendant(
    of: find.byType(MissingSongRow),
    matching: find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is ShapeDecoration &&
          (w.decoration as ShapeDecoration).color == color,
    ),
  );
}

bool _rowFocused(WidgetTester tester) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  return find
      .ancestor(
        of: find.byElementPredicate((e) => e == focused),
        matching: find.byType(MissingSongRow),
      )
      .evaluate()
      .isNotEmpty;
}

Future<void> _tabToRow(WidgetTester tester) async {
  for (var i = 0; i < 4 && !_rowFocused(tester); i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
}

void main() {
  testWidgets('shows the file name, Not in library and a crossed-out note', (
    tester,
  ) async {
    await _pump(tester, const MissingSongRow(path: _path, detail: 'when'));

    expect(find.text('lost.flac'), findsOneWidget);
    expect(find.text('Not in library'), findsOneWidget);
    expect(find.text('when'), findsOneWidget);
    expect(find.byIcon(AppIcons.musicOff), findsOneWidget);
    expect(find.byIcon(AppIcons.musicNoteOutlined), findsNothing);
  });

  testWidgets('is dimmed to 0.6', (tester) async {
    await _pump(tester, const MissingSongRow(path: _path));

    final dim = tester.widget<Opacity>(
      find
          .descendant(
            of: find.byType(MissingSongRow),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(dim.opacity, 0.6);
  });

  testWidgets('Tab focuses the row and shows a highlight', (tester) async {
    await _pump(tester, const MissingSongRow(path: _path));
    expect(_highlight(tester), findsNothing);

    await _tabToRow(tester);

    expect(_rowFocused(tester), isTrue);
    expect(_highlight(tester), findsOneWidget);
  });

  testWidgets('focus from a pointer or touch shows no highlight', (
    tester,
  ) async {
    final manager = FocusManager.instance;
    final strategy = manager.highlightStrategy;
    addTearDown(() => manager.highlightStrategy = strategy);
    await _pump(tester, const MissingSongRow(path: _path));

    manager.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
    await _tabToRow(tester);
    expect(_rowFocused(tester), isTrue);
    expect(_highlight(tester), findsNothing);

    manager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    await tester.pump();
    expect(_highlight(tester), findsOneWidget);
  });

  testWidgets('the Menu key opens the menu from the keyboard', (tester) async {
    final calls = <_Call>[];
    await _pump(
      tester,
      MissingSongRow(
        path: _path,
        onMenu: ({required viaKeyboard, required at}) =>
            calls.add((viaKeyboard: viaKeyboard, at: at)),
      ),
    );

    await _tabToRow(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pump();

    expect(calls.map((c) => c.viaKeyboard), [true]);
  });

  testWidgets('a right click opens the menu at the pointer', (tester) async {
    final calls = <_Call>[];
    await _pump(
      tester,
      MissingSongRow(
        path: _path,
        onMenu: ({required viaKeyboard, required at}) =>
            calls.add((viaKeyboard: viaKeyboard, at: at)),
      ),
    );

    final at = tester.getCenter(find.text('lost.flac'));
    await tester.tapAt(at, buttons: kSecondaryButton);
    await tester.pump();

    expect(calls, [(viaKeyboard: false, at: at)]);
  });

  testWidgets('without onMenu it is still focusable and has no menu', (
    tester,
  ) async {
    await _pump(tester, const MissingSongRow(path: _path));

    expect(find.byType(ContextMenuRegion), findsOneWidget);
    expect(
      find.byType(MenuKeyboardRegion),
      findsNothing,
      reason: 'the region adds no menu keys, right click or long press',
    );
    await _tabToRow(tester);
    expect(_rowFocused(tester), isTrue);
  });

  testWidgets('showFavorite adds a heart that cannot add', (tester) async {
    await _pump(tester, const MissingSongRow(path: _path, showFavorite: true));

    final heart = tester.widget<FavoriteButton>(find.byType(FavoriteButton));
    expect(heart.path, _path);
    expect(heart.canAdd, isFalse);
  });

  testWidgets('no heart by default', (tester) async {
    await _pump(tester, const MissingSongRow(path: _path));

    expect(find.byType(FavoriteButton), findsNothing);
  });
}
