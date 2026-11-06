import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/layered_modal/layered_modal_top_bar.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('actions are drawn before the close button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LayeredModalTopBar(
            title: 'Title',
            actions: [Icon(Icons.settings, key: ValueKey('gear'))],
          ),
        ),
      ),
    );
    final gearX = tester.getTopLeft(find.byKey(const ValueKey('gear'))).dx;
    final closeX = tester.getTopLeft(find.byIcon(AppIcons.close)).dx;
    expect(gearX, lessThan(closeX));
  });

  testWidgets('long title with two actions does not overflow at 280 px', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: LayeredModalTopBar(
                title: 'A very long modal title that cannot possibly fit in one line',
                actions: [Icon(Icons.settings), Icon(Icons.info)],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byIcon(AppIcons.close), findsOneWidget);
  });
}
