import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_source_chip.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<int> pump(
    WidgetTester tester, {
    List<({String id, int count})> sources = const [],
    String? selected,
  }) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: LyricsPickerSourceChip(
              sources: sources,
              providerNames: const {'a': 'Alpha', 'b': 'Beta'},
              selected: selected,
              onPressed: () => pressed++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(OutlinedButton));
    return pressed;
  }

  testWidgets('no results: enabled, plain label, fixed width', (tester) async {
    final pressed = await pump(tester);
    expect(find.text('All sources'), findsOneWidget);
    expect(tester.getSize(find.byType(OutlinedButton)).width, 200);
    expect(pressed, 1);
  });

  testWidgets('two sources: the label counts them', (tester) async {
    await pump(
      tester,
      sources: const [(id: 'a', count: 2), (id: 'b', count: 1)],
    );
    expect(find.text('All sources (2)'), findsOneWidget);
  });

  testWidgets('a filter shows the source name with the full name as tooltip', (
    tester,
  ) async {
    await pump(
      tester,
      sources: const [(id: 'a', count: 2), (id: 'b', count: 1)],
      selected: 'b',
    );
    expect(find.text('Beta'), findsOneWidget);
    expect(find.byTooltip('Beta'), findsOneWidget);
  });
}
