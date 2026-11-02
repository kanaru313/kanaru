import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/add_to_playlist/playlist_picker_footer.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, int selected) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 440,
              child: PlaylistPickerFooter(
                selected: selected,
                busy: false,
                onAdd: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final selected in [1, 3]) {
    testWidgets('Add button is flush right with $selected selected', (
      tester,
    ) async {
      await pump(tester, selected);
      final row = tester.getRect(
        find.descendant(
          of: find.byType(PlaylistPickerFooter),
          matching: find.byType(Row),
        ),
      );
      final add = tester.getRect(find.byType(FilledButton));
      expect((add.right - row.right).abs(), lessThan(0.5));
      expect(tester.takeException(), isNull);
    });
  }
}
