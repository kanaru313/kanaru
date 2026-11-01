import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/settings_focus.dart';
import 'package:kanaru/features/settings/settings_page_scaffold.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:material_ui/material_ui.dart';

/// A page much taller than the 600 px window, with the target at the bottom.
Widget _page(SettingsAnchor? focus, {bool withTarget = true}) =>
    SettingsPageScaffold(
      title: 'Page',
      focus: focus,
      children: [
        const SizedBox(height: 1500),
        if (withTarget)
          SettingsFocusTarget(
            anchor: SettingsAnchor.playbackTranslation,
            child: ListTile(title: const Text('group'), onTap: () {}),
          ),
        const SizedBox(height: 200),
      ],
    );

Widget _app(Widget home, {bool reduced = false}) => ProviderScope(
  overrides: [settingsFileProvider.overrideWithValue(null)],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: home,
  ),
);

Future<void> _setUp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Advances time by [d] and builds the frame.
Future<void> _wait(WidgetTester tester, Duration d) async {
  await tester.pump(d);
  await tester.pump();
}

Material _tint(WidgetTester tester) => tester.widget<Material>(
  find
      .descendant(
        of: find.byType(SettingsFocusTarget),
        matching: find.byType(Material),
      )
      .first,
);

bool _pulsing(WidgetTester tester) => _tint(tester).type == MaterialType.canvas;

double _offset(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

/// Enough to end a pulse that began at the latest frame before it.
const _finish = Duration(milliseconds: 2600);

void main() {
  testWidgets('scrolls to the target, then pulses and settles', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(_app(_page(SettingsAnchor.playbackTranslation)));

    await tester.pump();
    await _wait(tester, const Duration(milliseconds: 400));
    expect(_offset(tester), greaterThan(0));
    final rect = tester.getRect(find.text('group'));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(600));

    expect(_pulsing(tester), isFalse, reason: 'not before the settle delay');
    await _wait(tester, settingsFocusSettleDelay);
    await _wait(tester, const Duration(milliseconds: 400));
    expect(_pulsing(tester), isTrue);
    expect(_tint(tester).color!.a, greaterThan(0));
    await _wait(tester, const Duration(milliseconds: 1500));
    expect(_pulsing(tester), isTrue);
    await _wait(tester, _finish);
    expect(_pulsing(tester), isFalse);
  });

  testWidgets('waits for a page slide-in before pulsing', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(_app(const SizedBox()));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => _page(SettingsAnchor.playbackTranslation),
      ),
    );

    await _wait(tester, const Duration(milliseconds: 300));
    expect(_pulsing(tester), isFalse);
    await _wait(tester, settingsFocusSettleDelay);
    await _wait(tester, const Duration(milliseconds: 400));
    expect(_pulsing(tester), isTrue);
    expect(_offset(tester), greaterThan(0));
    await _wait(tester, _finish);
    expect(_pulsing(tester), isFalse);
  });

  testWidgets('reduced motion jumps and shows a static tint, then none', (
    tester,
  ) async {
    await _setUp(tester);
    await tester.pumpWidget(
      _app(_page(SettingsAnchor.playbackTranslation), reduced: true),
    );

    await tester.pump();
    expect(_offset(tester), greaterThan(0), reason: 'one frame, no animation');
    await _wait(
      tester,
      settingsFocusSettleDelay + const Duration(milliseconds: 100),
    );
    final alpha = _tint(tester).color!.a;
    expect(_pulsing(tester), isTrue);
    await _wait(tester, const Duration(milliseconds: 1300));
    expect(_pulsing(tester), isTrue);
    expect(_tint(tester).color!.a, alpha);
    await _wait(tester, const Duration(milliseconds: 200));
    expect(_pulsing(tester), isFalse);
  });

  testWidgets('the row ink paints on the target while it pulses', (
    tester,
  ) async {
    await _setUp(tester);
    await tester.pumpWidget(_app(_page(SettingsAnchor.playbackTranslation)));
    await _wait(
      tester,
      settingsFocusSettleDelay + const Duration(milliseconds: 400),
    );

    // The tile's nearest Material is the target's, so its ink is drawn above
    // the tint.
    final nearest = find
        .ancestor(of: find.byType(ListTile), matching: find.byType(Material))
        .first;
    expect(tester.widget<Material>(nearest), same(_tint(tester)));
    expect(_pulsing(tester), isTrue);
  });

  testWidgets('a new anchor restarts the pulse; a rebuild does not', (
    tester,
  ) async {
    await _setUp(tester);
    final focus = ValueNotifier<SettingsAnchor?>(
      SettingsAnchor.playbackTranslation,
    );
    final rebuilds = ValueNotifier<int>(0);
    addTearDown(focus.dispose);
    addTearDown(rebuilds.dispose);
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder(
          valueListenable: rebuilds,
          builder: (_, _, _) => ValueListenableBuilder(
            valueListenable: focus,
            builder: (_, value, _) => _page(value),
          ),
        ),
      ),
    );
    await _wait(
      tester,
      settingsFocusSettleDelay + const Duration(milliseconds: 400),
    );
    await _wait(tester, _finish);
    expect(_pulsing(tester), isFalse);

    // A real rebuild with the same focus (a theme change): nothing.
    rebuilds.value++;
    await tester.pump();
    await _wait(
      tester,
      settingsFocusSettleDelay + const Duration(milliseconds: 400),
    );
    expect(_pulsing(tester), isFalse);

    // Dropped, then asked for again: pulses again.
    focus.value = null;
    await tester.pump();
    focus.value = SettingsAnchor.playbackTranslation;
    await tester.pump();
    await _wait(
      tester,
      settingsFocusSettleDelay + const Duration(milliseconds: 400),
    );
    expect(_pulsing(tester), isTrue);

    // Dropping the parameter does not stop a running pulse.
    focus.value = null;
    await _wait(tester, const Duration(milliseconds: 500));
    expect(_pulsing(tester), isTrue);
  });

  testWidgets('an anchor that is not built does nothing and throws nothing', (
    tester,
  ) async {
    await _setUp(tester);
    await tester.pumpWidget(
      _app(_page(SettingsAnchor.libraryFolders, withTarget: false)),
    );
    await _wait(tester, settingsFocusSettleDelay);
    await _wait(tester, _finish);
    expect(tester.takeException(), isNull);
    expect(_offset(tester), 0);
  });

  testWidgets('a missing row falls back to its group', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(_app(_page(SettingsAnchor.deepLKey)));
    await tester.pump();
    await _wait(tester, const Duration(milliseconds: 400));
    expect(_offset(tester), greaterThan(0));
    await _wait(
      tester,
      settingsFocusSettleDelay + const Duration(milliseconds: 400),
    );
    expect(_pulsing(tester), isTrue);
    await _wait(tester, _finish);
  });

  testWidgets('leaving mid-pulse leaves no timer behind', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(_app(_page(SettingsAnchor.playbackTranslation)));
    await _wait(
      tester,
      settingsFocusSettleDelay + const Duration(milliseconds: 400),
    );
    expect(_pulsing(tester), isTrue);

    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pump(settingsFocusPulseDuration);
  });

  group('through the router', () {
    late GoRouter router;

    Future<void> pumpRouter(WidgetTester tester) async {
      await _setUp(tester);
      router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
          GoRoute(
            path: settingsLibraryRoute,
            builder: (_, _) => _page(SettingsAnchor.playbackTranslation),
          ),
          GoRoute(
            path: settingsPlaybackRoute,
            builder: (_, state) {
              return _page(
                SettingsAnchor.byId(
                  state.uri.queryParameters[settingsFocusParam],
                ),
              );
            },
            routes: [
              GoRoute(path: 'sub', builder: (_, _) => const Text('sub')),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsFileProvider.overrideWithValue(null)],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
          ),
        ),
      );
    }

    String location() =>
        router.routerDelegate.currentConfiguration.uri.toString();

    testWidgets('the URL is plain after use and the page is kept', (
      tester,
    ) async {
      await pumpRouter(tester);
      router.go(settingsFocusLocation(SettingsAnchor.playbackTranslation));
      await tester.pump();
      await tester.pump();

      expect(location(), settingsPlaybackRoute);
      expect(find.byType(SettingsPageScaffold), findsOneWidget);
      final state = tester.state(find.byType(SettingsPageScaffold));
      await _wait(
        tester,
        settingsFocusSettleDelay + const Duration(milliseconds: 400),
      );
      expect(_pulsing(tester), isTrue, reason: 'the strip keeps the pulse');
      expect(tester.state(find.byType(SettingsPageScaffold)), same(state));
      await _wait(tester, _finish);
    });

    testWidgets('the same link twice pulses twice', (tester) async {
      await pumpRouter(tester);
      final link = settingsFocusLocation(SettingsAnchor.playbackTranslation);
      router.go(link);
      await tester.pump();
      await _wait(
        tester,
        settingsFocusSettleDelay + const Duration(milliseconds: 400),
      );
      await _wait(tester, _finish);
      expect(_pulsing(tester), isFalse);

      router.go(link);
      await tester.pump();
      await _wait(
        tester,
        settingsFocusSettleDelay + const Duration(milliseconds: 400),
      );
      expect(_pulsing(tester), isTrue);
      await _wait(tester, _finish);
    });

    testWidgets('the strip leaves another location alone', (tester) async {
      await pumpRouter(tester);

      // A page mounted with a focus while the router is on another path
      // that also carries the parameter: it is not this page's to strip.
      router.go('$settingsLibraryRoute?$settingsFocusParam=translation');
      await tester.pump();
      await tester.pump();

      expect(
        location(),
        '$settingsLibraryRoute?$settingsFocusParam=translation',
      );
      expect(find.byType(SettingsPageScaffold), findsOneWidget);
      await _wait(tester, _finish);
    });

    testWidgets('a page opened right after the link is not popped', (
      tester,
    ) async {
      await pumpRouter(tester);
      router.go(settingsFocusLocation(SettingsAnchor.playbackTranslation));
      await tester.pump();
      router.go('$settingsPlaybackRoute/sub');
      await tester.pumpAndSettle();

      expect(location(), '$settingsPlaybackRoute/sub');
      expect(find.text('sub'), findsOneWidget);
    });

    testWidgets('leaving at once and coming back does not pulse', (
      tester,
    ) async {
      await pumpRouter(tester);
      router.go(settingsFocusLocation(SettingsAnchor.playbackTranslation));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      router.go('/settings');
      await tester.pumpAndSettle();
      router.go(settingsPlaybackRoute);
      await tester.pump();
      await _wait(
        tester,
        settingsFocusSettleDelay + const Duration(milliseconds: 400),
      );

      expect(_pulsing(tester), isFalse);
      expect(location(), settingsPlaybackRoute);
    });
  });
}
