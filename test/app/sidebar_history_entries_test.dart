import 'package:flutter/material.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/app/shell/app_destination.dart';
import 'package:kanaru/app/shell/sidebar/sidebar.dart';
import 'package:kanaru/app/shell/sidebar/sidebar_item.dart';
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

  testWidgets('the third group is queue history, favorites, history', (
    tester,
  ) async {
    await pumpApp(tester, wide);
    double top(String label) => tester.getTopLeft(_inSidebar(label)).dy;

    expect(top('Queue history'), lessThan(top('Favorites')));
    expect(top('Favorites'), lessThan(top('History')));
  });

  testWidgets('the sidebar opens queue history at /queue-history', (
    tester,
  ) async {
    await pumpApp(tester, wide);

    await tester.tap(_inSidebar('Queue history'));
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
    expect(_item(tester, 'Queue history').selected, isTrue);
  });

  testWidgets('renders the new rows in Vietnamese', (tester) async {
    await pumpApp(tester, wide, locale: const Locale('vi'));
    expect(_inSidebar('Lịch sử hàng đợi'), findsOneWidget);
    expect(_inSidebar('Hàng đợi hiện tại'), findsNothing);
  });
}
