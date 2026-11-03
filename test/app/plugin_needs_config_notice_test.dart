import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/app/shell/plugin_needs_config_notice.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_needs_config_notices.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:kanaru/shared/translation_plugin_routes.dart';
import 'package:material_ui/material_ui.dart';

const _id = 'plugin-abc123def456';

class _OpenNowPlaying extends NowPlayingOpen {
  @override
  bool build() => true;
}

void main() {
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pump(WidgetTester tester, {Locale? locale}) async {
    container = ProviderContainer(
      overrides: [nowPlayingOpenProvider.overrideWith(_OpenNowPlaying.new)],
    );
    addTearDown(container.dispose);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const PluginNeedsConfigNoticeHost(
            child: Scaffold(body: Text('home')),
          ),
        ),
        GoRoute(
          path: '$lyricsSourcesRoute/plugin/:$lyricsPluginIdParam',
          builder: (_, _) => const Text('lyrics plugin page'),
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

  testWidgets('two reports behind another snack bar queue only one', (
    tester,
  ) async {
    await pump(tester);
    showForeign(tester);
    await tester.pumpAndSettle();

    report(PluginKind.lyrics);
    await tester.pump();
    report(PluginKind.lyrics);
    await tester.pump();

    // The foreign one ends, ours shows once and, when closed, nothing more.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Demo needs configuration'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.text('home')))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
