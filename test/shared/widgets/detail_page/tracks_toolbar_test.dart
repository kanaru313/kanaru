import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/in_page_filter.dart';
import 'package:kanaru/shared/widgets/detail_page/tracks_toolbar.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late InPageFilterController filter;
  final openButton = find.byTooltip('Filter in this page');
  const trailingKey = Key('trailing');

  Future<void> pump(WidgetTester tester, Widget toolbar) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: SizedBox(width: 600, child: toolbar)),
      ),
    );
  }

  testWidgets('shows the given summary and trailing right of the filter '
      'button', (tester) async {
    filter = InPageFilterController();
    addTearDown(filter.dispose);
    await pump(
      tester,
      TracksToolbar(
        summary: '40 listens · 12 songs',
        filter: filter,
        trailing: const [SizedBox(key: trailingKey, width: 40, height: 40)],
      ),
    );

    expect(find.text('40 listens · 12 songs'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(trailingKey)).dx,
      greaterThanOrEqualTo(tester.getTopRight(openButton).dx),
    );
  });

  testWidgets('the opened filter leaves trailing visible and tappable', (
    tester,
  ) async {
    var taps = 0;
    filter = InPageFilterController();
    addTearDown(filter.dispose);
    await pump(
      tester,
      TracksToolbar(
        summary: 'summary',
        filter: filter,
        trailing: [
          GestureDetector(
            key: trailingKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(width: 40, height: 40),
          ),
        ],
      ),
    );
    await tester.tap(openButton);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close'), findsOneWidget);
    await tester.tap(find.byKey(trailingKey));
    expect(taps, 1);
    expect(
      tester.getTopLeft(find.byKey(trailingKey)).dx,
      greaterThanOrEqualTo(tester.getTopRight(find.byTooltip('Close')).dx),
    );
  });

  testWidgets('the sliver toolbar still shows "N songs · length"', (
    tester,
  ) async {
    filter = InPageFilterController();
    addTearDown(filter.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverTracksToolbar(
                songCount: 3,
                durationMs: 61000,
                filter: filter,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('3 songs · 1:01'), findsOneWidget);
  });
}
