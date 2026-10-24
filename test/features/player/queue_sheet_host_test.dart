import 'package:flutter/services.dart';
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

  late ProviderContainer container;
  var barPresses = 0;
  late QueueSheetController controller;
  bool? openSeenByButton;

  /// The app around the host: a page and, when [bottomInset] is set, a "bar"
  /// button in the strip at the bottom that the sheet leaves uncovered.
  Widget app({double bottomInset = 0, bool closed = false}) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QueueSheetHost(
            bottomInset: bottomInset,
            closed: closed,
            onOpenChanged: changes.add,
            child: Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        controller = QueueSheetHost.of(context);
                        return const Center(child: Text('behind'));
                      },
                    ),
                  ),
                  if (bottomInset > 0)
                    SizedBox(
                      height: bottomInset,
                      child: Builder(
                        builder: (context) {
                          openSeenByButton = QueueSheetHost.isOpenOf(context);
                          return TextButton(
                            onPressed: () => barPresses++,
                            child: const Text('bar'),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

  Future<QueueSheetController> pumpHost(
    WidgetTester tester, {
    bool animations = true,
    double bottomInset = 0,
  }) async {
    barPresses = 0;
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
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
    );
    addTearDown(container.dispose);
    await container.read(playerServiceProvider.notifier).openTracks([
      const Track(uri: '/music/a.mp3', title: 'a'),
      const Track(uri: '/music/b.mp3', title: 'b'),
    ]);
    await tester.pumpWidget(app(bottomInset: bottomInset));
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

  group('above a bottom bar', () {
    testWidgets('the scrim and sheet stop at the inset', (tester) async {
      final controller = await pumpHost(tester, bottomInset: 100);
      controller.open();
      await tester.pumpAndSettle();

      expect(tester.getBottomLeft(panel()).dy, 500);
      expect(tester.getRect(scrim()).bottom, 500);
    });

    testWidgets('the sheet is a solid surface', (tester) async {
      final controller = await pumpHost(tester);
      controller.open();
      await tester.pumpAndSettle();

      final material = tester.widget<Material>(
        find.ancestor(of: panel(), matching: find.byType(Material)).first,
      );
      final scheme = Theme.of(tester.element(panel())).colorScheme;
      expect(material.color, scheme.surfaceContainerLow);
      expect(material.color!.a, 1);
    });

    testWidgets('a control in the bar works and the sheet stays open', (
      tester,
    ) async {
      final controller = await pumpHost(tester, bottomInset: 100);
      controller.open();
      await tester.pumpAndSettle();

      expect(find.text('bar').hitTestable(), findsOneWidget);
      await tester.tap(find.text('bar'));
      await tester.pumpAndSettle();

      expect(barPresses, 1);
      expect(controller.isOpen, isTrue);
      expect(panel(), findsOneWidget);
    });

    testWidgets('Esc closes the sheet while a bar control has focus', (
      tester,
    ) async {
      final controller = await pumpHost(tester, bottomInset: 100);
      controller.open();
      await tester.pumpAndSettle();
      await tester.tap(find.text('bar'));
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(controller.isOpen, isFalse);
      expect(panel(), findsNothing);
    });

    testWidgets('a control in the bar sees the sheet open and closed', (
      tester,
    ) async {
      final controller = await pumpHost(tester, bottomInset: 100);
      expect(openSeenByButton, isFalse);

      controller.open();
      await tester.pump();
      expect(openSeenByButton, isTrue);

      controller.close();
      await tester.pump();
      expect(openSeenByButton, isFalse);
    });

    testWidgets('closed closes an open sheet', (tester) async {
      final controller = await pumpHost(tester, bottomInset: 100);
      controller.open();
      await tester.pumpAndSettle();

      await tester.pumpWidget(app(bottomInset: 100, closed: true));
      await tester.pumpAndSettle();

      expect(controller.isOpen, isFalse);
      expect(panel(), findsNothing);
      expect(changes, [true, false]);
    });
  });
}
