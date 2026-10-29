import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/in_page_no_match.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, {String? message}) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: InPageNoMatch(query: 'abc', message: message),
          ),
        ),
      );

  testWidgets('shows the default text with the query', (tester) async {
    await pump(tester);

    expect(find.textContaining('abc'), findsOneWidget);
  });

  testWidgets('shows the given message instead of the default', (tester) async {
    await pump(tester, message: 'Nothing here');

    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.textContaining('abc'), findsNothing);
  });
}
