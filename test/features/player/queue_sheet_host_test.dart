import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/queue/queue_panel.dart';
import 'package:kanaru/features/player/queue/queue_sheet_host.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  late List<bool> changes;

  Future<QueueSheetController> pumpHost(
    WidgetTester tester, {
    bool animations = true,
  }) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (!animations) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    changes = [];
    late QueueSheetController controller;
    final container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
    );
    addTearDown(container.dispose);
    await container.read(playerServiceProvider.notifier).openTracks([
      const Track(uri: '/music/a.mp3', title: 'a'),
      const Track(uri: '/music/b.mp3', title: 'b'),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QueueSheetHost(
            onOpenChanged: changes.add,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  controller = QueueSheetHost.of(context);
                  return const Center(child: Text('behind'));
                },
              ),
            ),
          ),
        ),
      ),
    );
    return controller;
  }

  Finder panel() => find.byType(QueuePanel);
  double panelLeft(WidgetTester tester) => tester.getTopLeft(panel()).dx;

  Finder scrim() => find.byWidgetPredicate(
    (w) => w is ColoredBox && w.color.a == 0.5 && w.color.r == 0,
  );

  double scrimOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.ancestor(of: scrim(), matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;

  testWidgets('slides in from the right over 400 ms and slides back', (
    tester,
  ) async {
    final controller = await pumpHost(tester);
    expect(panel(), findsNothing);

    controller.open();
    await tester.pump();
    // Starts fully off screen, scrim clear.
    expect(panelLeft(tester), 1000);
    expect(scrimOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 200));
    expect(panelLeft(tester), inExclusiveRange(600, 1000));

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(panelLeft(tester), 600);
    expect(tester.getSize(panel()).width, 400);
    expect(scrimOpacity(tester), 1);
    expect(scrim(), findsOneWidget);
    // Only the position animates: no fade or scale on the panel itself.
    expect(
      find.ancestor(
        of: panel(),
        matching: find.descendant(
          of: find.byType(QueueSheetHost),
          matching: find.byType(ScaleTransition),
        ),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: panel(),
        matching: find.descendant(
          of: find.byType(QueueSheetHost),
          matching: find.byType(FadeTransition),
        ),
      ),
      findsNothing,
    );

    controller.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(panel(), findsOneWidget);
    expect(panelLeft(tester), inExclusiveRange(600, 1000));
    await tester.pumpAndSettle();
    expect(panel(), findsNothing);
    expect(changes, [true, false]);
  });

  testWidgets('tapping the scrim closes it', (tester) async {
    final controller = await pumpHost(tester);
    controller.open();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(100, 300));
    await tester.pumpAndSettle();

    expect(controller.isOpen, isFalse);
    expect(panel(), findsNothing);
  });

  testWidgets('the scrim blocks the screen behind', (tester) async {
    final controller = await pumpHost(tester);
    controller.open();
    await tester.pumpAndSettle();

    expect(find.text('behind').hitTestable(), findsNothing);
  });

  testWidgets('opening twice or closing while closed does nothing', (
    tester,
  ) async {
    final controller = await pumpHost(tester);
    controller.close();
    controller.open();
    controller.open();
    await tester.pumpAndSettle();

    expect(changes, [true]);
  });

  testWidgets('reduced motion shows and hides it at once', (tester) async {
    final controller = await pumpHost(tester, animations: false);

    controller.open();
    await tester.pump();
    expect(panelLeft(tester), 600);

    controller.close();
    await tester.pump();
    expect(panel(), findsNothing);
  });
}
