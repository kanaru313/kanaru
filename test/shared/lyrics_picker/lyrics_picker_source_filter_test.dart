import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_source_chips.dart';
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

  Future<void> open(WidgetTester tester, {String secondName = 'Beta'}) async {
    tester.view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await createHarness([
      LyricsProviderRegistration(
        _Source('alpha', 'Alpha', 'Song alpha', 'alpha words'),
      ),
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

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  testWidgets('a chip that hides the selected row selects a shown one', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(ChoiceChip), findsNWidgets(3));

    await tester.tap(chip('Beta'));
    await settle(tester);
    expect(find.text('Song alpha'), findsNothing);
    expect(find.text('beta words'), findsOneWidget);
    expect(find.text('alpha words'), findsNothing);

    await tester.tap(chip('Alpha'));
    await settle(tester);
    expect(find.text('Song beta'), findsNothing);
    expect(find.text('alpha words'), findsOneWidget);
    expect(find.text('beta words'), findsNothing);
  });

  testWidgets('a new search shows every source again', (tester) async {
    await open(tester);
    await tester.tap(chip('Beta'));
    await settle(tester);
    expect(find.text('Song alpha'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await settle(tester);

    expect(find.text('Song alpha'), findsOneWidget);
    expect(find.text('Song beta'), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(find.byType(ChoiceChip).first).selected,
      isTrue,
    );
  });

  testWidgets('an 80-character source name shortens in tile and chip', (
    tester,
  ) async {
    await open(tester, secondName: longName);

    expect(tester.takeException(), isNull);
    // The chip is capped, and its tooltip has the full name.
    final chipLabel = find.descendant(
      of: find.byType(LyricsPickerSourceChips),
      matching: find.text(longName),
    );
    expect(chipLabel, findsOneWidget);
    expect(tester.getSize(chipLabel).width, lessThanOrEqualTo(160));
    expect(find.byTooltip(longName), findsOneWidget);
    // The tile's name is capped too.
    final tileName = find.descendant(
      of: find.byType(ListTile),
      matching: find.text(longName),
    );
    expect(tileName, findsOneWidget);
    expect(tester.getSize(tileName).width, lessThanOrEqualTo(180));
  });
}
