import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/app/shell/sidebar/sidebar.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/lyrics_sources/plugin_detail_page.dart';
import 'package:kanaru/features/online_sources/online_sources_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/fake_audio_backend.dart';
import '../features/online_sources/online_test_support.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  RecordsProvider records, {
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      ...onlineOverrides(records),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KanaruApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder get _entry =>
    find.descendant(of: find.byType(Sidebar), matching: find.text('Online'));

String _location(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

void main() {
  testWidgets('the sidebar has no Online entry without a source plugin', (
    tester,
  ) async {
    await _pump(tester, testRecords(const AsyncValue.data([])));

    expect(_entry, findsNothing);
  });

  testWidgets('the sidebar has no Online entry while the list loads', (
    tester,
  ) async {
    await _pump(tester, testRecords(const AsyncValue.loading()));

    expect(_entry, findsNothing);
  });

  testWidgets('the sidebar has no Online entry when the list cannot be read', (
    tester,
  ) async {
    await _pump(
      tester,
      testRecords(AsyncValue.error(StateError('x'), StackTrace.empty)),
    );

    expect(_entry, findsNothing);
  });

  testWidgets('with a source plugin the entry sits after Home and opens it', (
    tester,
  ) async {
    final records = testRecords(AsyncValue.data([sourceRecord()]));
    final container = await _pump(tester, records);

    expect(_entry, findsOneWidget);
    double top(String label) => tester
        .getTopLeft(
          find.descendant(of: find.byType(Sidebar), matching: find.text(label)),
        )
        .dy;
    expect(top('Home'), lessThan(top('Online')));
    expect(top('Online'), lessThan(top('Songs')));

    await tester.tap(_entry);
    await tester.pumpAndSettle();

    expect(_location(container), '/online');
    expect(find.byType(OnlineSourcesScreen), findsOneWidget);
    expect(find.text('Tube'), findsOneWidget);
  });

  testWidgets('removing the last source plugin drops the entry', (
    tester,
  ) async {
    final records = testRecords(AsyncValue.data([sourceRecord()]));
    final container = await _pump(tester, records);
    await tester.tap(_entry);
    await tester.pumpAndSettle();

    container.read(records.notifier).set(const AsyncValue.data([]));
    await tester.pumpAndSettle();

    expect(_entry, findsNothing);
    // The page stays reachable and says there is no plugin.
    expect(find.text('Open plugin store'), findsOneWidget);
  });

  testWidgets('a source plugin page opens under /online/plugin/:id', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      testRecords(AsyncValue.data([sourceRecord()])),
    );
    container.read(routerProvider).go('/online/plugin/$sourceId');
    await tester.pumpAndSettle();

    expect(_location(container), '/online/plugin/$sourceId');
    expect(find.byType(PluginDetailPage), findsOneWidget);
    expect(find.byType(OnlineSourcesScreen), findsNothing);
  });
}
