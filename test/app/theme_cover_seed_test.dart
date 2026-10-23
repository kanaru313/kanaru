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

/// An app palette the test can change, like a new track's cover.
class _MutablePalette extends AppCoverPaletteNotifier {
  @override
  CoverPalette? build() => null;

  void show(CoverPalette? palette) => state = palette;
}

void main() {
  group('buildTheme', () {
    test('the same inputs give the same theme object', () {
      expect(
        identical(
          buildTheme(null, Brightness.light, coverSeed: _red),
          buildTheme(null, Brightness.light, coverSeed: _red),
        ),
        isTrue,
      );
      final platform = ColorScheme.fromSeed(seedColor: Colors.teal);
      expect(
        identical(
          buildTheme(platform, Brightness.dark),
          buildTheme(
            ColorScheme.fromSeed(seedColor: Colors.teal),
            Brightness.dark,
          ),
        ),
        isTrue,
      );
    });

    test('another seed or brightness gives another theme', () {
      final base = buildTheme(null, Brightness.light, coverSeed: _red);
      expect(
        identical(
          base,
          buildTheme(null, Brightness.light, coverSeed: Colors.green),
        ),
        isFalse,
      );
      expect(
        identical(base, buildTheme(null, Brightness.dark, coverSeed: _red)),
        isFalse,
      );
    });

    test('the cache drops the least recently used theme', () {
      Color seed(int i) => Color(0xFF100000 + i);
      ThemeData build(int i) =>
          buildTheme(null, Brightness.light, coverSeed: seed(i));
      final themes = [for (var i = 0; i < 8; i++) build(i)];
      final first = themes[0], second = themes[1];
      // Eight kept: the first is still there, and now the most recent.
      expect(identical(build(0), first), isTrue);
      // One more pushes out the least recent (1), not the first.
      build(8);
      expect(identical(build(0), first), isTrue);
      expect(identical(build(1), second), isFalse);
      // Many more push the first out too; answers stay correct.
      for (var i = 20; i < 40; i++) {
        build(i);
      }
      expect(identical(build(0), first), isFalse);
      expect(build(0).colorScheme, ColorScheme.fromSeed(seedColor: seed(0)));
    });

    test('the platform accent does not split entries of a cover seed', () {
      final a = ColorScheme.fromSeed(seedColor: Colors.teal);
      final b = ColorScheme.fromSeed(seedColor: Colors.orange);
      expect(
        identical(
          buildTheme(a, Brightness.light, coverSeed: _red),
          buildTheme(b, Brightness.light, coverSeed: _red),
        ),
        isTrue,
      );
    });

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

    testWidgets('a new cover changes the theme within one frame', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          audioBackendProvider.overrideWithValue(FakeAudioBackend()),
          appCoverPaletteProvider.overrideWith(_MutablePalette.new),
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
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .themeAnimationDuration,
        Duration.zero,
      );

      final context = tester.element(find.byType(Navigator).first);
      final before = Theme.of(context).colorScheme;
      (container.read(appCoverPaletteProvider.notifier) as _MutablePalette)
          .show(const CoverPalette(seed: _red, colors: [_red]));
      // One pump, no time passing: no theme animation is running.
      await tester.pump();
      final brightness = before.brightness;
      expect(
        Theme.of(tester.element(find.byType(Navigator).first)).colorScheme,
        ColorScheme.fromSeed(seedColor: _red, brightness: brightness),
      );
      expect(
        Theme.of(tester.element(find.byType(Navigator).first)).colorScheme,
        isNot(before),
      );
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
