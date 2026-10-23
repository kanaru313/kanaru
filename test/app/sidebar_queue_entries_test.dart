import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/app/shell/app_destination.dart';
import 'package:kanaru/app/shell/sidebar/sidebar.dart';
import 'package:kanaru/app/shell/sidebar/sidebar_item.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/queue/queue_panel.dart';
import 'package:kanaru/features/playlists/queue_history_routes.dart';
import 'package:kanaru/features/playlists/queue_history_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/fake_audio_backend.dart';
import 'app_shell_test.dart' show narrow, pumpApp, wide;

Finder _inSidebar(String label) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(label));

SidebarItem _item(WidgetTester tester, String label) => tester.widget(
  find.byWidgetPredicate((w) => w is SidebarItem && w.label == label),
);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(KanaruApp)));

Future<void> _queueTwo(WidgetTester tester) async {
  await _container(tester)
      .read(playerServiceProvider.notifier)
      .openTracks([Track.fromPath('/m/a.mp3'), Track.fromPath('/m/b.mp3')]);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {});

  test('the route literal matches the destination', () {
    expect(queueHistoryPath, AppDestination.queueHistory.path);
    expect(queueHistoryLocation(4), '/queue-history/4');
  });

  testWidgets('the third group is queue history, current queue, favorites, '
      'history', (tester) async {
    await pumpApp(tester, wide);
    double top(String label) => tester.getTopLeft(_inSidebar(label)).dy;

    expect(top('Queue history'), lessThan(top('Current queue')));
    expect(top('Current queue'), lessThan(top('Favorites')));
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

  testWidgets('current queue is disabled while nothing is queued', (
    tester,
  ) async {
    await pumpApp(tester, wide);
    expect(_item(tester, 'Current queue').onTap, isNull);
  });

  testWidgets(
    'current queue opens and closes the queue sheet, lit while open',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpApp(tester, wide);
      await _queueTwo(tester);
      final selectedBefore = _item(tester, 'Home').selected;

      await tester.tap(_inSidebar('Current queue'));
      await tester.pumpAndSettle();
      expect(find.byType(QueuePanel), findsOneWidget);
      expect(_item(tester, 'Current queue').selected, isTrue);
      // A page stays selected: the sheet is not a page.
      expect(_item(tester, 'Home').selected, selectedBefore);

      _item(tester, 'Current queue').onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(QueuePanel), findsNothing);
      expect(_item(tester, 'Current queue').selected, isFalse);
    },
  );

  testWidgets('the collapsed rail opens the sheet from the icon', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester, wide);
    await _queueTwo(tester);
    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();

    final item = find.byWidgetPredicate(
      (w) => w is SidebarItem && w.label == 'Current queue' && w.compact,
    );
    expect(item, findsOneWidget);
    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(find.byType(QueuePanel), findsOneWidget);
  });

  testWidgets('in the drawer it closes the drawer and opens the sheet', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester, narrow);
    await _queueTwo(tester);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.tap(_inSidebar('Current queue'));
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsNothing);
    expect(find.byType(QueuePanel), findsOneWidget);
  });

  testWidgets('renders the new rows in Vietnamese', (tester) async {
    await pumpApp(tester, wide, locale: const Locale('vi'));
    expect(_inSidebar('Lịch sử hàng đợi'), findsOneWidget);
    expect(_inSidebar('Hàng đợi hiện tại'), findsOneWidget);
  });
}
