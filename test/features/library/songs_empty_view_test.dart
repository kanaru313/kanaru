import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/songs/songs_empty_view.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('first run in a small window with large text scrolls to the '
      'choose folder button instead of overflowing', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var chosen = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 180,
              child: SongsEmptyView(
                kind: SongsEmptyKind.noRoots,
                onChooseFolder: () => chosen++,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    final button = find.byType(FilledButton);
    expect(tester.getRect(button).top, greaterThan(180), reason: 'below');
    await tester.drag(find.byType(SongsEmptyView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(180));
    await tester.tap(button);
    expect(chosen, 1);
  });
}
