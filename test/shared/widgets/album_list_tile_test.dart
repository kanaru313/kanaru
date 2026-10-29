import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/album_list_tile.dart';
import 'package:kanaru/shared/widgets/library_row.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const album = AlbumSummary(
    key: AlbumKey('artist', 'title'),
    title: 'Blue',
    artist: 'Joni',
    trackCount: 3,
    durationMs: 600000,
    addedAt: 0,
  );

  Future<void> pump(
    WidgetTester tester, {
    required bool showTotals,
    TextScaler scaler = TextScaler.noScaling,
    void Function(ThemeData theme)? onTheme,
  }) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            onTheme?.call(Theme.of(context));
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: Scaffold(
                body: AlbumListTile(
                  album: album,
                  onTap: () {},
                  showTotals: showTotals,
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  testWidgets('shows the song count and length by default', (tester) async {
    await pump(tester, showTotals: true);

    expect(find.text('Blue'), findsOneWidget);
    expect(find.text('3 songs • 10 min'), findsOneWidget);
  });

  testWidgets('showTotals false hides the totals and keeps three lines of '
      'height', (tester) async {
    const scaler = TextScaler.linear(2);
    late double expected;

    Future<double> heightOf({required bool showTotals}) async {
      await pump(
        tester,
        showTotals: showTotals,
        scaler: scaler,
        onTheme: (theme) => expected = libraryRowExtent(theme, scaler),
      );
      return tester.getSize(find.byType(AlbumListTile)).height;
    }

    final withTotals = await heightOf(showTotals: true);
    final withoutTotals = await heightOf(showTotals: false);

    expect(find.text('Blue'), findsOneWidget);
    expect(find.textContaining('songs'), findsNothing);
    expect(find.textContaining('min'), findsNothing);
    expect(withTotals, expected);
    expect(withoutTotals, expected);
    expect(expected, greaterThan(libraryRowMinHeight));
  });
}
