import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/add_to_playlist/playlist_picker_footer.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int selected,
    bool busy = false,
    double width = 440,
    double scale = 1,
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: PlaylistPickerFooter(
                selected: selected,
                busy: busy,
                onAdd: () {},
              ),
            ),
          ),
        ),
      ),
    );
    // Non-default locales load their delegates asynchronously.
    await tester.pump(const Duration(milliseconds: 50));
  }

  void expectFlushRight(WidgetTester tester) {
    final row = tester.getRect(find.byKey(PlaylistPickerFooter.rowKey));
    final add = tester.getRect(find.byType(FilledButton));
    expect((add.right - row.right).abs(), lessThan(0.5));
    expect(tester.takeException(), isNull);
  }

  for (final selected in [0, 1, 3]) {
    testWidgets('Add button is flush right with $selected selected', (
      tester,
    ) async {
      await pump(tester, selected: selected);
      expectFlushRight(tester);
    });
  }

  testWidgets('Add button is flush right while busy', (tester) async {
    await pump(tester, selected: 3, busy: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expectFlushRight(tester);
  });

  testWidgets('long vi label at 2x text and 300px does not overflow', (
    tester,
  ) async {
    await pump(
      tester,
      selected: 12,
      width: 300,
      scale: 2,
      locale: const Locale('vi'),
    );
    expectFlushRight(tester);
    final add = tester.getRect(find.byType(FilledButton));
    expect(add.width, lessThanOrEqualTo(PlaylistPickerFooter.addMaxWidth));
  });
}
