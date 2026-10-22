import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/theme.dart';
import 'package:kanaru/core/cover_colors/cover_palette.dart';
import 'package:kanaru/core/cover_colors/playing_cover_palette_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/fake_audio_backend.dart';

const _red = Color(0xFFC62828);

/// A fixed app palette, standing in for the playing cover's colors.
class _FixedPalette extends AppCoverPaletteNotifier {
  _FixedPalette(this.palette);

  final CoverPalette? palette;

  @override
  CoverPalette? build() => palette;
}

void main() {
  group('buildTheme', () {
    for (final brightness in Brightness.values) {
      test('a cover seed sets the $brightness scheme', () {
        expect(
          buildTheme(null, brightness, coverSeed: _red).colorScheme,
          ColorScheme.fromSeed(seedColor: _red, brightness: brightness),
        );
      });

      test('a cover seed wins over the platform accent ($brightness)', () {
        final platform = ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness,
        );
        expect(
          buildTheme(platform, brightness, coverSeed: _red).colorScheme,
          ColorScheme.fromSeed(seedColor: _red, brightness: brightness),
        );
      });

      test('without a cover seed nothing changes ($brightness)', () {
        final platform = ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness,
        );
        expect(
          buildTheme(platform, brightness).colorScheme,
          platform.harmonized(),
        );
        expect(
          buildTheme(null, brightness).colorScheme,
          ColorScheme.fromSeed(
            seedColor: kanaruSeedColor,
            brightness: brightness,
          ),
        );
      });
    }
  });

  group('KanaruApp', () {
    Future<MaterialApp> pumpApp(
      WidgetTester tester, {
      CoverPalette? palette,
    }) async {
      final container = ProviderContainer(
        overrides: [
          audioBackendProvider.overrideWithValue(FakeAudioBackend()),
          if (palette != null)
            appCoverPaletteProvider.overrideWith(() => _FixedPalette(palette)),
        ],
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const KanaruApp(),
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget<MaterialApp>(find.byType(MaterialApp));
    }

    testWidgets('moves to new colors over 300 ms', (tester) async {
      final app = await pumpApp(tester);
      expect(app.themeAnimationDuration, coverThemeTransition);
      expect(coverThemeTransition, const Duration(milliseconds: 300));
    });

    testWidgets('switches at once when the system asks for less motion', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final app = await pumpApp(tester);
      expect(app.themeAnimationDuration, Duration.zero);
    });

    testWidgets('uses the cover seed in both themes', (tester) async {
      final app = await pumpApp(
        tester,
        palette: const CoverPalette(seed: _red, colors: [_red]),
      );
      expect(
        app.theme!.colorScheme,
        ColorScheme.fromSeed(seedColor: _red, brightness: Brightness.light),
      );
      expect(
        app.darkTheme!.colorScheme,
        ColorScheme.fromSeed(seedColor: _red, brightness: Brightness.dark),
      );
    });

    testWidgets('a gray cover keeps the default colors', (tester) async {
      final app = await pumpApp(
        tester,
        palette: const CoverPalette(seed: null, colors: [Color(0xFF808080)]),
      );
      expect(
        app.theme!.colorScheme,
        buildTheme(null, Brightness.light).colorScheme,
      );
    });
  });
}
