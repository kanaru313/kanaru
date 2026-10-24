import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/play_history_writes.dart';
import 'package:kanaru/features/home/home_paged_list.dart';
import 'package:kanaru/features/home/home_paged_view.dart';
import 'package:kanaru/features/home/home_routes.dart';
import 'package:kanaru/features/home/home_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'home_test_harness.dart';

void main() {
  final now = DateTime(2026, 10, 24, 12);

  final routes = [
    GoRoute(
      path: '/home',
      builder: (_, _) => const HomeScreen(),
      routes: homeRoutes,
    ),
  ];

  group('narrow window and large text', () {
    for (final (width, scale) in [(480.0, 1.0), (480.0, 2.0), (320.0, 2.0)]) {
      for (final page in ['recent-albums', 'recent-artists']) {
        testWidgets('$page at $width px and x$scale has no overflow', (
          tester,
        ) async {
          final h = HomeHarness(now: now);
          for (var i = 0; i < 6; i++) {
            await h.addTrack(
              '/m/$i.mp3',
              artist: 'Artist with a rather long name $i',
              album: 'Album with a rather long title $i',
            );
            await h.db.insertLibraryPlay(
              path: '/m/$i.mp3',
              playedAt: now.millisecondsSinceEpoch - 1000 * (i + 1),
              listenedMs: 200000,
            );
            await h.db.insertLibraryPlay(
              path: '/m/$i.mp3',
              playedAt: DateTime(2025, 10, 23, 9).millisecondsSinceEpoch,
              listenedMs: 200000,
            );
          }
          await h.pump(
            tester,
            const SizedBox(),
            width: width,
            textScale: scale,
            routes: routes,
            initialLocation: '/home/$page',
          );
          expect(tester.takeException(), isNull);
          expect(find.textContaining('rather long'), findsWidgets);
        });
      }
    }

    testWidgets('recently added at 480 px and x2 has no overflow', (
      tester,
    ) async {
      final h = HomeHarness(now: now);
      for (var i = 0; i < 4; i++) {
        await h.addTrack('/m/$i.mp3', addedAt: now.millisecondsSinceEpoch - i);
      }
      await h.pump(
        tester,
        const SizedBox(),
        width: 480,
        textScale: 2,
        routes: routes,
        initialLocation: '/home/recently-added?window=all',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('T /m/0.mp3'), findsOneWidget);
    });
  });

  group('failed read', () {
    Future<void> showFailed(
      WidgetTester tester,
      HomeHarness h,
      VoidCallback onRetry,
    ) => h.pump(
      tester,
      HomePagedView<int>(
        state: const HomePagedState<int>(
          rows: [1, 2, 3],
          loading: false,
          failed: true,
        ),
        onLoadMore: () {},
        onRetry: onRetry,
        emptyIcon: Icons.music_note,
        emptyText: 'empty',
        builder: (context, controller, rows) => ListView(
          controller: controller,
          children: [for (final r in rows) Text('row $r')],
        ),
      ),
    );

    testWidgets('keeps the rows and offers a retry under them', (tester) async {
      final h = HomeHarness(now: now);
      var retries = 0;
      await showFailed(tester, h, () => retries++);
      expect(find.text('row 1'), findsOneWidget);
      expect(find.text('Could not load the list'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      expect(retries, 1);
    });
  });
}
