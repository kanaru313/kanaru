import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/shell/sidebar/sidebar.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/fake_audio_backend.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required bool animations,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        initialSettingsProvider.overrideWithValue(
          AppSettings(animations: animations),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KanaruApp()),
    );
    await tester.pumpAndSettle();
  }

  double sidebarWidth(WidgetTester tester) =>
      tester.getSize(find.byType(Sidebar)).width;

  testWidgets('with Animations off the sidebar collapses in one frame', (
    tester,
  ) async {
    await pumpShell(tester, animations: false);

    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pump();

    expect(sidebarWidth(tester), sidebarCompactWidth);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('with Animations on the sidebar slides', (tester) async {
    await pumpShell(tester, animations: true);

    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(sidebarWidth(tester), greaterThan(sidebarCompactWidth));
    await tester.pumpAndSettle();
    expect(sidebarWidth(tester), sidebarCompactWidth);
  });
}
