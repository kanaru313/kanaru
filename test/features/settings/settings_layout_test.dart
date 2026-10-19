import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  const sizes = [Size(480, 800), Size(760, 800), Size(1280, 800)];

  for (final language in ['en', 'vi']) {
    for (final size in sizes) {
      testWidgets(
        'settings fit a ${size.width.toInt()} px window in $language',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final container = ProviderContainer(
            overrides: [
              audioBackendProvider.overrideWithValue(FakeAudioBackend()),
              initialSettingsProvider.overrideWithValue(
                AppSettings(languageCode: language),
              ),
            ],
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const KanaruApp(),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byIcon(Icons.settings_outlined).hitTestable().first,
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final segments = find.byType(SegmentedButton<ThemePreference>);
          expect(segments.hitTestable(), findsOneWidget);

          // Every segment can be tapped, and the choice is applied.
          await tester.tap(
            find.descendant(
              of: segments,
              matching: find.byIcon(Icons.dark_mode_outlined),
            ),
          );
          await tester.pumpAndSettle();
          expect(container.read(settingsProvider).theme, ThemePreference.dark);

          final titleBar = find.byType(SegmentedButton<TitleBarPreference>);
          await tester.ensureVisible(titleBar);
          await tester.pumpAndSettle();
          expect(titleBar.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
