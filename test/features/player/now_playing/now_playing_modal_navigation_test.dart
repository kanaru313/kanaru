import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/features/player/now_playing/now_playing_modal_navigation.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/layered_modal/layered_modal_route.dart';

class _OpenNowPlaying extends NowPlayingOpen {
  @override
  bool build() => true;
}

void main() {
  testWidgets('closes the stack and Now Playing, then goes to the location', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [nowPlayingOpenProvider.overrideWith(_OpenNowPlaying.new)],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => TextButton(
            onPressed: () => showLayeredModal<void>(
              context,
              builder: (_) => Builder(
                builder: (modalContext) => Column(
                  children: [
                    const Text('parent'),
                    TextButton(
                      onPressed: () => showLayeredModal<void>(
                        modalContext,
                        builder: (_) => const Text('child'),
                      ),
                      child: const Text('open child'),
                    ),
                    TextButton(
                      onPressed: () =>
                          leaveNowPlayingTo(modalContext, '/there'),
                      child: const Text('leave'),
                    ),
                  ],
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        GoRoute(path: '/there', builder: (_, _) => const Text('there')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('leave'));
    await tester.pumpAndSettle();

    expect(find.text('parent'), findsNothing);
    expect(container.read(nowPlayingOpenProvider), isFalse);
    expect(find.text('there'), findsOneWidget);
  });
}
