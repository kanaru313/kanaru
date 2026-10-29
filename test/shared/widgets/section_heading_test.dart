import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/section_heading.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    SectionHeading heading, {
    double width = 800,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: heading),
        ),
      ),
    ),
  );

  testWidgets('the title is a header and a count shows after it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, const SectionHeading(title: 'Albums', count: 12));

    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Albums')),
      isSemantics(label: 'Albums', isHeader: true),
    );
    expect(
      tester.getTopLeft(find.text('12')).dx,
      greaterThan(tester.getTopRight(find.text('Albums')).dx),
    );
    semantics.dispose();
  });

  testWidgets('no count shows no number', (tester) async {
    await pump(tester, const SectionHeading(title: 'Albums'));
    expect(find.text('0'), findsNothing);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('the chevron says "See all" and taps through', (tester) async {
    var taps = 0;
    await pump(
      tester,
      SectionHeading(title: 'Albums', count: 3, onSeeAll: () => taps++),
    );

    expect(find.byTooltip('See all'), findsOneWidget);
    await tester.tap(find.byTooltip('See all'));
    expect(taps, 1);
  });

  testWidgets('without onSeeAll the chevron stays but is disabled', (
    tester,
  ) async {
    await pump(tester, const SectionHeading(title: 'Albums'));

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
    expect(find.byTooltip('See all'), findsOneWidget);
  });

  testWidgets('a long title shrinks; count and chevron stay visible', (
    tester,
  ) async {
    await pump(
      tester,
      SectionHeading(
        title: 'A very long section title ' * 8,
        count: 128,
        onSeeAll: () {},
      ),
      width: 300,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('128'), findsOneWidget);
    final chevron = tester.getRect(find.byType(IconButton));
    expect(chevron.right, lessThanOrEqualTo(300));
    expect(
      tester.getRect(find.text('128')).right,
      lessThanOrEqualTo(chevron.left),
    );
  });
}
