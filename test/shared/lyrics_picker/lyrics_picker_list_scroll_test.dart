import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_results_pane.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/lookup_test_harness.dart';

/// A source with [count] results.
class _Source extends FakeLyricsProvider {
  _Source(String id, String name, int count) : _name = name, super(id: id) {
    searchResult = [
      for (var i = 0; i < count; i++)
        fakeCandidate(
          providerId: id,
          remoteId: '$id$i',
          title: 'Song $id $i',
          body: LyricsBody(syncedLrc: '[00:01.00] $id words $i'),
        ),
    ];
  }

  final String _name;

  @override
  String get displayName => _name;
}

void main() {
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
    Size size = const Size(1280, 900),
    int perSource = 6,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await createHarness([
      LyricsProviderRegistration(_Source('alpha', 'Alpha', perSource)),
      LyricsProviderRegistration(_Source('beta', 'Beta', perSource)),
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

  Finder resultList() => find.descendant(
    of: find.byType(LyricsPickerResultsPane),
    matching: find.byType(ListView),
  );
  ScrollController listController(WidgetTester tester) =>
      tester.widget<ListView>(resultList()).controller!;

  Finder contentBox() => find.byWidgetPredicate(
    (w) => w is SizedBox && w.width == 840 && w.height != null,
  );

  testWidgets('dialog is 720 tall in a 900 tall window', (tester) async {
    await open(tester);
    expect(tester.getSize(contentBox()).height, 720);
    // The list shows at least two full tiles.
    final tile = tester.getSize(find.byType(ListTile).first).height;
    expect(tester.getSize(resultList()).height, greaterThanOrEqualTo(tile * 2));
  });

  testWidgets('a small window keeps the floor and scrolls', (tester) async {
    await open(tester, size: const Size(500, 360));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(contentBox()).height, 440);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('a new search puts the list back at the top', (tester) async {
    await open(tester, perSource: 12);
    final controller = listController(tester);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(controller.offset, greaterThan(0));

    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await settle(tester);

    expect(controller.offset, 0);
    final first = find.text('Song alpha 0');
    expect(first, findsOneWidget);
    expect(
      tester.getTopLeft(first).dy,
      greaterThanOrEqualTo(tester.getTopLeft(resultList()).dy),
    );
  });

  testWidgets('a source filter puts the list back at the top', (tester) async {
    await open(tester, perSource: 12);
    final controller = listController(tester);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(controller.offset, greaterThan(0));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Beta'));
    await settle(tester);

    expect(controller.offset, 0);
  });
}
