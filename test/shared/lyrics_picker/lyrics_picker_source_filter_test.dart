import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_dialog.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/lookup_test_harness.dart';

/// A source with its own name and one answer.
class _Source extends FakeLyricsProvider {
  _Source(String id, this._name, String title, String words) : super(id: id) {
    searchResult = [
      fakeCandidate(
        providerId: id,
        remoteId: id,
        title: title,
        body: LyricsBody(syncedLrc: '[00:01.00] $words'),
      ),
    ];
  }

  final String _name;

  @override
  String get displayName => _name;
}

void main() {
  final longName = List.filled(80, 'W').join();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> open(
    WidgetTester tester, {
    String secondName = 'Beta',
    Size size = const Size(1280, 900),
    bool onlyOne = false,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await createHarness([
      LyricsProviderRegistration(
        _Source('alpha', 'Alpha', 'Song alpha', 'alpha words'),
      ),
      if (!onlyOne)
        LyricsProviderRegistration(
          _Source('beta', secondName, 'Song beta', 'beta words'),
        ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showLyricsPicker(
                navigator: Navigator.of(context),
                container: h.container,
                target: fakeTarget,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await settle(tester);
  }

  Finder chip() => find.byType(OutlinedButton);
  // A row of the Search sources modal (the result tiles have no trailing).
  Finder item(String name) => find.byWidgetPredicate(
    (w) => w is SelectionRow && w.title == name && w.trailing != null,
  );

  Future<void> pick(WidgetTester tester, String name) async {
    await tester.tap(chip());
    // A long row title scrolls forever, so the modal never settles.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(item(name));
    await settle(tester);
  }

  testWidgets('the chip sits left of the field, in the Search row', (
    tester,
  ) async {
    await open(tester);
    final field = find.byType(TextField);
    final search = find.widgetWithText(FilledButton, 'Search');
    expect(find.text('All sources (2)'), findsOneWidget);
    expect(tester.getSize(chip()).width, 200);
    expect(tester.getCenter(chip()).dy, tester.getCenter(field).dy);
    expect(tester.getCenter(search).dy, tester.getCenter(field).dy);
    expect(
      tester.getTopRight(chip()).dx,
      lessThan(tester.getTopLeft(field).dx),
    );
  });

  testWidgets('a source that hides the selected row selects a shown one', (
    tester,
  ) async {
    await open(tester);

    await pick(tester, 'Beta');
    expect(find.text('Song alpha'), findsNothing);
    expect(find.text('beta words'), findsOneWidget);
    expect(find.text('alpha words'), findsNothing);

    await pick(tester, 'Alpha');
    expect(find.text('Song beta'), findsNothing);
    expect(find.text('alpha words'), findsOneWidget);
    expect(find.text('beta words'), findsNothing);

    await pick(tester, 'All sources');
    expect(find.text('Song alpha'), findsOneWidget);
    expect(find.text('Song beta'), findsOneWidget);
  });

  testWidgets('a new search shows every source again', (tester) async {
    await open(tester);
    await pick(tester, 'Beta');
    expect(find.text('Song alpha'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await settle(tester);

    expect(find.text('Song alpha'), findsOneWidget);
    expect(find.text('Song beta'), findsOneWidget);
    expect(find.text('All sources (2)'), findsOneWidget);
  });

  testWidgets('the field does not move with the filter, even an 80-char one', (
    tester,
  ) async {
    await open(tester, secondName: longName);
    final field = find.byType(TextField);
    final x = tester.getTopLeft(field).dx;

    await pick(tester, longName);
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(field).dx, x);
    expect(tester.getSize(chip()).width, 200);
    expect(find.byTooltip(longName), findsOneWidget);

    // The tile's name is capped too.
    final tileName = find.descendant(
      of: find.byType(SelectionRow),
      matching: find.text(longName),
    );
    expect(tileName, findsOneWidget);
    expect(tester.getSize(tileName).width, lessThanOrEqualTo(180));
  });

  testWidgets('Esc in the Search sources modal keeps the dialog', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(chip());
    await settle(tester);
    expect(find.text('Search sources'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    expect(find.text('Search sources'), findsNothing);
    expect(find.byType(LyricsPickerDialog), findsOneWidget);
  });

  testWidgets('the chip takes the keyboard: Enter opens Search sources', (
    tester,
  ) async {
    await open(tester);
    // The field has focus on open; the chip is the field's previous stop.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pump();
    expect(Focus.of(tester.element(chip())).hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);

    expect(find.text('Search sources'), findsOneWidget);
  });

  testWidgets('one source: the chip is enabled and opens the modal', (
    tester,
  ) async {
    await open(tester);
    final x = tester.getTopLeft(find.byType(TextField)).dx;
    await tester.pumpWidget(const SizedBox());
    await open(tester, onlyOne: true);
    expect(find.text('All sources'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(chip()).onPressed, isNotNull);
    expect(tester.getTopLeft(find.byType(TextField)).dx, x);

    await tester.tap(chip());
    await settle(tester);
    expect(find.text('Search sources'), findsOneWidget);
    expect(item('Alpha'), findsOneWidget);
  });

  testWidgets('a small window does not overflow', (tester) async {
    await open(tester, size: const Size(500, 360));
    await tester.tap(chip());
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
