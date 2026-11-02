import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/album_links_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/album_modal/album_more_button.dart';
import 'package:kanaru/shared/widgets/album_list_tile.dart';
import 'package:kanaru/shared/widgets/song_card.dart';
import 'package:material_ui/material_ui.dart';

import 'album_modal_test_support.dart';

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  final summary = linksOf().summary;

  Future<void> pump(
    WidgetTester tester, {
    bool withMore = true,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumModalLinksProvider(testAlbumKey)
              .overrideWith((ref) async => linksOf()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: AlbumListTile(
              album: summary,
              onTap: () {},
              onQueueAction: withMore ? (_) {} : null,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the ⋮ button shows only with a queue action', (tester) async {
    await pump(tester);
    expect(find.byType(AlbumMoreButton), findsOneWidget);
    await pump(tester, withMore: false);
    expect(find.byType(AlbumMoreButton), findsNothing);
  });

  testWidgets('it is dim at rest and full while the row is focused', (
    tester,
  ) async {
    await pump(tester);
    double opacity() => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byType(AlbumMoreButton),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(opacity(), 0.6);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(opacity(), 1);
  });

  testWidgets('a tap opens the album modal with Go to album', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('More options'));
    await settleModal(tester);
    expect(albumModalAction('album'), findsOneWidget);
  });

  testWidgets('Tab goes row, then the ⋮ button; Enter focuses the first row', (
    tester,
  ) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final rowFocus = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNot(rowFocus));
    expect(
      find.descendant(
        of: find.byType(AlbumMoreButton),
        matching: find.byElementPredicate(
          (e) => e == FocusManager.instance.primaryFocus?.context,
        ),
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleModal(tester);
    final ctx = FocusManager.instance.primaryFocus?.context;
    expect(
      find.descendant(
        of: albumModalAction('album'),
        matching: find.byElementPredicate((e) => e == ctx),
      ),
      findsWidgets,
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('the row keeps the prototype height at scale $scale', (
      tester,
    ) async {
      await pump(tester, withMore: false, scale: scale);
      final without = tester.getSize(find.byType(SongCardFrame)).height;
      await pump(tester, scale: scale);
      expect(tester.getSize(find.byType(SongCardFrame)).height, without);
    });
  }
}
