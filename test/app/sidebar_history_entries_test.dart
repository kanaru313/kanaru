import 'package:flutter/material.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/app/shell/app_destination.dart';
import 'package:kanaru/app/shell/sidebar/sidebar.dart';
import 'package:kanaru/app/shell/sidebar/sidebar_item.dart';
import 'package:kanaru/features/history/history_routes.dart';
import 'package:kanaru/features/history/most_played_screen.dart';
import 'package:kanaru/features/playlists/queue_history_routes.dart';
import 'package:kanaru/features/playlists/queue_history_screen.dart';

import 'app_shell_test.dart' show pumpApp, wide;

Finder _inSidebar(String label) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(label));

SidebarItem _item(WidgetTester tester, String label) => tester.widget(
  find.byWidgetPredicate((w) => w is SidebarItem && w.label == label),
);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(KanaruApp)));

void main() {
  setUp(() {});

  test('the route literal matches the destination', () {
    expect(queueHistoryPath, AppDestination.queueHistory.path);
    expect(queueHistoryLocation(4), '/queue-history/4');
  });

  test('the Most played literal matches the destination', () {
    expect(mostPlayedPath, AppDestination.mostPlayed.path);
  });

  testWidgets('the third group is playlists, favorites, queues, history, '
      'most played', (tester) async {
    await pumpApp(tester, wide);
    double top(String label) => tester.getTopLeft(_inSidebar(label)).dy;

    expect(top('Playlists'), lessThan(top('Favorites')));
    expect(top('Favorites'), lessThan(top('Queues')));
    expect(top('Queues'), lessThan(top('History')));
    expect(top('History'), lessThan(top('Most played')));
  });

  testWidgets('the sidebar opens Most played at /most-played', (tester) async {
    await pumpApp(tester, wide);

    await tester.tap(_inSidebar('Most played'));
    await tester.pumpAndSettle();

    expect(
      _container(tester)
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/most-played',
    );
    expect(find.byType(MostPlayedScreen), findsOneWidget);
    expect(_item(tester, 'Most played').selected, isTrue);
    expect(_item(tester, 'History').selected, isFalse);
  });

  testWidgets('the sidebar opens queue history at /queue-history', (
    tester,
  ) async {
    await pumpApp(tester, wide);

    await tester.tap(_inSidebar('Queues'));
    await tester.pumpAndSettle();

    expect(
      _container(tester)
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/queue-history',
    );
    expect(find.byType(QueueHistoryScreen), findsOneWidget);
    expect(_item(tester, 'Queues').selected, isTrue);
  });

  testWidgets('renders the new rows in Vietnamese', (tester) async {
    await pumpApp(tester, wide, locale: const Locale('vi'));
    expect(_inSidebar('Các hàng đợi'), findsOneWidget);
    expect(_inSidebar('Phát nhiều nhất'), findsOneWidget);
    expect(_inSidebar('Hàng đợi hiện tại'), findsNothing);
  });
}
