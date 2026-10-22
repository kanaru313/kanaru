import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/app/shell/app_destination.dart';
import 'package:kanaru/features/history/history_routes.dart';
import 'package:kanaru/features/history/history_track_screen.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('the route literal matches the destination', () {
    expect(historyPath, AppDestination.history.path);
  });

  group('song history address', () {
    final paths = {
      'spaces and reserved characters': 'a b+c%20#?&=.flac',
      'non-ASCII': '/m/Ánh/日本語.mp3',
      'a 4000 character path': '/m/${'dir/' * 998}a.flac',
    };

    for (final MapEntry(:key, :value) in paths.entries) {
      testWidgets('reaches the page unchanged: $key', (tester) async {
        final router = GoRouter(
          initialLocation: historyPath,
          routes: [
            GoRoute(
              path: historyPath,
              builder: (context, state) => const SizedBox(),
              routes: historyRoutes,
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        router.go(historyTrackLocation(value));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<HistoryTrackScreen>(find.byType(HistoryTrackScreen))
              .path,
          value,
        );
      });
    }

    test('the location is below the History page', () {
      expect(
        Uri.parse(historyTrackLocation('/m/a.flac')).path,
        '$historyPath/track',
      );
    });
  });
}
