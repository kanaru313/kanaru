import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/app/shell/plugin_needs_config_notice.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_needs_config_notices.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:kanaru/shared/translation_plugin_routes.dart';
import 'package:kanaru/shared/widgets/app_snack_bar.dart';
import 'package:material_ui/material_ui.dart';

const _id = 'plugin-abc123def456';

class _OpenNowPlaying extends NowPlayingOpen {
  @override
  bool build() => true;
}

void main() {
  late ProviderContainer container;
  late GoRouter router;
  var clock = DateTime(2026);

  Future<void> pump(WidgetTester tester, {Locale? locale}) async {
    container = ProviderContainer(
      overrides: [nowPlayingOpenProvider.overrideWith(_OpenNowPlaying.new)],
    );
    addTearDown(container.dispose);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => PluginNeedsConfigNoticeHost(
            now: () => clock,
            child: const Scaffold(body: Text('home')),
          ),
        ),
        GoRoute(
          path: '$lyricsSourcesRoute/plugin/:$lyricsPluginIdParam',
          builder: (_, _) => const Text('lyrics plugin page'),
        ),
        GoRoute(
          path: lyricsSourcesRoute,
          builder: (_, _) => const Text('lyrics sources page'),
        ),
        GoRoute(
          path: settingsPlaybackRoute,
          builder: (_, _) => const Text('playback settings'),
        ),
        GoRoute(
          path: translationPluginRoutePattern,
          builder: (_, _) => const Text('translate plugin page'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale ?? const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void report(PluginKind kind, {String name = 'Demo'}) => container
      .read(pluginNeedsConfigNoticesProvider.notifier)
      .report(_id, name, kind);

  void reportFor(String id, String name) => container
      .read(pluginNeedsConfigNoticesProvider.notifier)
      .report(id, name, PluginKind.lyrics);

  String location() =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('a report shows the warning with Open config', (tester) async {
    await pump(tester);
    expect(find.byType(SnackBar), findsNothing);

    report(PluginKind.lyrics);
    await tester.pumpAndSettle();

    expect(find.text('Demo needs configuration'), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Open config'), findsOneWidget);
  });

  testWidgets('the Vietnamese wording', (tester) async {
    await pump(tester, locale: const Locale('vi'));
    report(PluginKind.lyrics);
    await tester.pumpAndSettle();

    expect(find.text('Demo cần được cấu hình'), findsOneWidget);
    expect(find.text('Mở cấu hình'), findsOneWidget);
  });

  testWidgets('a second report for the same plugin replaces the first', (
    tester,
  ) async {
    await pump(tester);
    report(PluginKind.lyrics);
    await tester.pumpAndSettle();
    report(PluginKind.lyrics, name: 'Demo again');
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Demo again needs configuration'), findsOneWidget);
    expect(find.text('Demo needs configuration'), findsNothing);
  });

  testWidgets('the same report twice shows twice', (tester) async {
    await pump(tester);
    report(PluginKind.lyrics);
    await tester.pumpAndSettle();
    final first = tester.widget<SnackBar>(find.byType(SnackBar));
    report(PluginKind.lyrics);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)), isNot(same(first)));
    expect(container.read(pluginNeedsConfigNoticesProvider)?.seq, 2);
  });

  testWidgets(
    'a lyrics plugin: the action opens its page, Now Playing closes',
    (tester) async {
      await pump(tester);
      report(PluginKind.lyrics);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open config'));
      await tester.pumpAndSettle();

      expect(location(), lyricsPluginRoute(_id));
      expect(container.read(nowPlayingOpenProvider), isFalse);
    },
  );

  testWidgets('a translate plugin: the action opens its translation page', (
    tester,
  ) async {
    await pump(tester);
    report(PluginKind.translate);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open config'));
    await tester.pumpAndSettle();

    expect(location(), translationPluginRoute(_id));
    expect(container.read(nowPlayingOpenProvider), isFalse);
  });

  // Another feature's snack bar, shown through the same messenger.
  void showForeign(WidgetTester tester) {
    ScaffoldMessenger.of(tester.element(find.text('home')))
        .showSnackBar(const SnackBar(content: Text('foreign'), persist: false));
  }

  testWidgets('another snack bar on screen is never closed; ours waits', (
    tester,
  ) async {
    await pump(tester);
    showForeign(tester);
    await tester.pumpAndSettle();

    report(PluginKind.lyrics);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('foreign'), findsOneWidget);
    expect(find.text('Demo needs configuration'), findsNothing);

    // Ours comes after the other one ends.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Demo needs configuration'), findsOneWidget);
  });

  void reportOne(String id, String name, PluginKind kind) => container
      .read(pluginNeedsConfigNoticesProvider.notifier)
      .report(id, name, kind);

  testWidgets('two plugins behind another snack bar: none lost, one notice', (
    tester,
  ) async {
    await pump(tester);
    showForeign(tester);
    await tester.pumpAndSettle();

    reportOne('a', 'Alpha', PluginKind.lyrics);
    await tester.pump();
    reportOne('b', 'Beta', PluginKind.lyrics);
    await tester.pump(const Duration(milliseconds: 500));

    // The other feature's bar is still there, untouched.
    expect(find.text('foreign'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Alpha and Beta need configuration'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.text('home')))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a queued notice dropped by another message is shown again', (
    tester,
  ) async {
    await pump(tester);
    final messenger = ScaffoldMessenger.of(tester.element(find.text('home')));
    showForeign(tester);
    await tester.pumpAndSettle();

    reportOne('a', 'Alpha', PluginKind.lyrics);
    await tester.pump();
    // Clears the queue: our bar never appears and never reports closing.
    messenger.showAppSnackBar(AppSnackBarKind.success, 'other done');
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    messenger.hideCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    clock = clock.add(const Duration(seconds: 31));
    reportOne('b', 'Beta', PluginKind.lyrics);
    await tester.pumpAndSettle();
    expect(find.text('Alpha and Beta need configuration'), findsOneWidget);
  });

  testWidgets('a report while ours slides in joins the same notice', (
    tester,
  ) async {
    await pump(tester);
    reportOne('a', 'Alpha', PluginKind.lyrics);
    await tester.pump(const Duration(milliseconds: 50));
    reportOne('b', 'Beta', PluginKind.lyrics);
    await tester.pumpAndSettle();

    expect(find.text('Alpha and Beta need configuration'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('two reports while ours is visible make one merged notice', (
    tester,
  ) async {
    await pump(tester);
    reportOne('a', 'Alpha', PluginKind.lyrics);
    await tester.pumpAndSettle();
    reportOne('b', 'Beta', PluginKind.translate);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Alpha and Beta need configuration'), findsOneWidget);
  });

  testWidgets('the same plugin twice lists one name', (tester) async {
    await pump(tester);
    reportOne('a', 'Alpha', PluginKind.lyrics);
    await tester.pumpAndSettle();
    reportOne('a', 'Alpha', PluginKind.lyrics);
    await tester.pumpAndSettle();

    expect(find.text('Alpha needs configuration'), findsOneWidget);
  });

  testWidgets('the list resets once the notice is closed', (tester) async {
    await pump(tester);
    reportOne('a', 'Alpha', PluginKind.lyrics);
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.text('home')))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    reportOne('b', 'Beta', PluginKind.lyrics);
    await tester.pumpAndSettle();

    expect(find.text('Beta needs configuration'), findsOneWidget);
  });

  testWidgets('four plugins: two names and a count', (tester) async {
    await pump(tester);
    for (final n in ['A', 'B', 'C', 'D']) {
      reportOne(n, n, PluginKind.lyrics);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('A, B and 2 more need configuration'), findsOneWidget);
  });

  testWidgets('three plugins: "1 more"', (tester) async {
    await pump(tester);
    for (final n in ['A', 'B', 'C']) {
      reportOne(n, n, PluginKind.lyrics);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('A, B and 1 more need configuration'), findsOneWidget);
  });

  Future<void> openFor(
    WidgetTester tester,
    List<(String, PluginKind)> plugins,
  ) async {
    await pump(tester);
    for (final (id, kind) in plugins) {
      reportOne(id, id, kind);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open config'));
    await tester.pumpAndSettle();
  }

  testWidgets('several lyrics plugins: Open config goes to the sources page', (
    tester,
  ) async {
    await openFor(tester, [('a', PluginKind.lyrics), ('b', PluginKind.lyrics)]);
    expect(location(), lyricsSourcesRoute);
    expect(container.read(nowPlayingOpenProvider), isFalse);
  });

  testWidgets('several translate plugins: Open config goes to translation', (
    tester,
  ) async {
    await openFor(tester, [
      ('a', PluginKind.translate),
      ('b', PluginKind.translate),
    ]);
    expect(
      location(),
      settingsFocusLocation(SettingsAnchor.playbackTranslation),
    );
  });

  testWidgets('mixed kinds: Open config goes to the sources page', (
    tester,
  ) async {
    await openFor(tester, [
      ('a', PluginKind.lyrics),
      ('b', PluginKind.translate),
    ]);
    expect(location(), lyricsSourcesRoute);
  });

  testWidgets('a bar dropped as lost that surfaces later closes itself', (
    tester,
  ) async {
    await pump(tester);
    final messenger = ScaffoldMessenger.of(tester.element(find.text('home')));
    messenger.showSnackBar(
      SnackBar(
        content: const Text('foreign'),
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
      ),
    );
    await tester.pumpAndSettle();
    reportFor('a', 'Alpha');
    await tester.pump(const Duration(seconds: 40));
    await tester.pumpAndSettle();
    expect(find.text('foreign'), findsOneWidget);

    clock = clock.add(const Duration(seconds: 31));
    reportFor('b', 'Beta');
    await tester.pump();
    messenger.hideCurrentSnackBar();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Alpha and Beta need configuration'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('the notice hides itself after 8 seconds', (tester) async {
    await pump(tester);
    report(PluginKind.lyrics);
    await tester.pumpAndSettle();
    expect(find.text('Demo needs configuration'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
