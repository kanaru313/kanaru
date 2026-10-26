import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/app/shell/app_destination.dart';
import 'package:kanaru/app/shell/sidebar/sidebar.dart';
import 'package:kanaru/app/shell/sidebar/sidebar_item.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/library/languages/languages_screen.dart';
import 'package:kanaru/features/settings/interface_setting_rows.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/fake_audio_backend.dart';
import 'app_shell_test.dart' show narrow, wide;

/// Songs and Genres hidden; the other four library tabs show.
const _twoHidden = {
  SidebarTab.albums,
  SidebarTab.artists,
  SidebarTab.languages,
  SidebarTab.folders,
};

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Size size,
  Set<SidebarTab> tabs,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      initialSettingsProvider.overrideWithValue(
        AppSettings(display: DisplayPrefs(sidebarTabs: tabs)),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KanaruApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder _inSidebar(String label) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(label));

void _expectTwoHidden() {
  for (final shown in ['Home', 'Albums', 'Artists', 'Languages', 'Folders']) {
    expect(_inSidebar(shown), findsOneWidget, reason: shown);
  }
  for (final hidden in ['Songs', 'Genres']) {
    expect(_inSidebar(hidden), findsNothing, reason: hidden);
  }
  for (final always in [
    'Playlists',
    'Favorites',
    'Queues',
    'History',
    'Most played',
  ]) {
    expect(_inSidebar(always), findsOneWidget, reason: always);
  }
  expect(find.text('Current queue'), findsNothing);
}

void main() {
  group('visibleSidebarGroups', () {
    List<AppDestination> flat(Set<SidebarTab> tabs) => [
      for (final g in visibleSidebarGroups(tabs)) ...g,
    ];

    test('lists every library page in order when all tabs show', () {
      final groups = visibleSidebarGroups(SidebarTab.values.toSet());
      expect(groups[0], [AppDestination.home]);
      expect(groups[1], [
        AppDestination.songs,
        AppDestination.albums,
        AppDestination.artists,
        AppDestination.genres,
        AppDestination.languages,
        AppDestination.folders,
      ]);
      expect(groups[2], [
        AppDestination.playlists,
        AppDestination.favorites,
        AppDestination.queueHistory,
        AppDestination.history,
        AppDestination.mostPlayed,
      ]);
    });

    test('hides songs', () {
      final tabs = SidebarTab.values.toSet()..remove(SidebarTab.songs);
      expect(flat(tabs), isNot(contains(AppDestination.songs)));
      expect(flat(tabs), contains(AppDestination.albums));
    });

    test('keeps one tab when all others are hidden', () {
      final groups = visibleSidebarGroups({SidebarTab.genres});
      expect(groups[1], [AppDestination.genres]);
    });

    test('home and the third group stay whatever the tabs', () {
      for (final tab in SidebarTab.values) {
        final groups = visibleSidebarGroups({tab});
        expect(groups.first, [AppDestination.home]);
        expect(groups.last, hasLength(5));
      }
    });

    test('every tab maps to one page, and chips follow sidebar order', () {
      expect(sidebarLibraryOrder.map(sidebarTabOf).toSet(), {
        ...SidebarTab.values,
      });
      expect(sidebarTabChipOrder, sidebarLibraryOrder.map(sidebarTabOf));
    });
  });

  testWidgets('the column hides the unselected tabs', (tester) async {
    await _pump(tester, wide, _twoHidden);
    _expectTwoHidden();
  });

  testWidgets('the collapsed rail hides them too', (tester) async {
    await _pump(tester, wide, _twoHidden);
    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(Sidebar)).width, 72);
    // Rail rows show their label as a tooltip only; count the icons.
    for (final d in AppDestination.values) {
      final shows =
          sidebarTabOf(d) == null || _twoHidden.contains(sidebarTabOf(d));
      if (d == AppDestination.search || d == AppDestination.settings) {
        continue;
      }
      expect(
        find.descendant(
          of: find.byType(Sidebar),
          matching: find.byWidgetPredicate(
            (w) => w is Icon && (w.icon == d.icon || w.icon == d.selectedIcon),
          ),
        ),
        shows ? findsWidgets : findsNothing,
        reason: d.name,
      );
    }
  });

  testWidgets('the drawer hides them too', (tester) async {
    await _pump(tester, narrow, _twoHidden);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    _expectTwoHidden();
  });

  testWidgets(
    'hiding the tab of the open page keeps the page, lights nothing',
    (tester) async {
      final container = await _pump(tester, wide, SidebarTab.values.toSet());
      await tester.tap(_inSidebar('Songs'));
      await tester.pumpAndSettle();

      container
          .read(settingsProvider.notifier)
          .setDisplay(const DisplayPrefs(sidebarTabs: {SidebarTab.albums}));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_inSidebar('Songs'), findsNothing);
      expect(
        tester
            .widgetList<SidebarItem>(find.byType(SidebarItem))
            .where((i) => i.selected),
        isEmpty,
      );
      expect(
        container
            .read(routerProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        '/songs',
      );
    },
  );

  testWidgets('/languages opens the Languages page', (tester) async {
    final container = await _pump(tester, wide, SidebarTab.values.toSet());
    await tester.tap(_inSidebar('Languages'));
    await tester.pumpAndSettle();

    expect(find.byType(LanguagesScreen), findsOneWidget);
    // No library database in this harness, so the page reports it.
    expect(find.text("Couldn't open the library"), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LanguagesScreen),
        matching: find.text('Languages'),
      ),
      findsOneWidget,
    );
    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/languages',
    );
  });
}
