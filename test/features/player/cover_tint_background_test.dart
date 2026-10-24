import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/cover_colors/cover_palette.dart';
import 'package:kanaru/core/cover_colors/playing_cover_palette_provider.dart';
import 'package:kanaru/features/player/cover_tint_background.dart';
import 'package:material_ui/material_ui.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

class _Palette extends AppCoverPaletteNotifier {
  @override
  CoverPalette? build() => null;

  void show(CoverPalette? palette) => state = palette;
}

void main() {
  group('readableGradientStops', () {
    for (final brightness in Brightness.values) {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: brightness,
      );
      final extremes = <String, List<Color>>{
        'white and pale yellow': const [Color(0xFFFFFFFF), Color(0xFFFFF9C4)],
        'black and deep blue': const [Color(0xFF000000), Color(0xFF0D1B4A)],
        'saturated': const [
          Color(0xFFFF0000),
          Color(0xFF00FF00),
          Color(0xFF0000FF),
        ],
      };
      extremes.forEach((name, palette) {
        test('$name on $brightness keeps text readable', () {
          final stops = readableGradientStops(
            palette,
            surface: scheme.surface,
            onSurface: scheme.onSurface,
            brightness: brightness,
          );
          for (final stop in stops) {
            expect(
              _contrast(
                scheme.onSurface,
                Color.alphaBlend(stop, scheme.surface),
              ),
              greaterThanOrEqualTo(4.5),
              reason: '$stop',
            );
          }
        });
      });
    }

    test('one color gives two stops, six give four', () {
      Iterable<Color> stops(int n) => readableGradientStops(
        [for (var i = 0; i < n; i++) Color(0xFF200000 + i * 0x1000)],
        surface: Colors.white,
        onSurface: Colors.black,
        brightness: Brightness.light,
      );
      expect(stops(1), hasLength(2));
      expect(stops(2), hasLength(2));
      expect(stops(6), hasLength(4));
    });
  });

  group('CoverTintBackground', () {
    late ProviderContainer container;

    Future<void> pump(WidgetTester tester) async {
      container = ProviderContainer(
        overrides: [appCoverPaletteProvider.overrideWith(_Palette.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            ),
            home: const CoverTintBackground(child: SizedBox.expand()),
          ),
        ),
      );
    }

    List<Color> gradient(WidgetTester tester) {
      final under = find.descendant(
        of: find.byType(CoverTintBackground),
        matching: find.byType(ColoredBox),
      );
      final surface = Theme.of(tester.element(find.byType(SizedBox)))
          .colorScheme
          .surface;
      final base = tester.widget<ColoredBox>(under.first).color;
      expect(base, surface, reason: 'the surface is painted under the tint');
      expect(base.a, 1.0, reason: 'always opaque');
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: under.first, matching: find.byType(DecoratedBox)),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, isNull, reason: 'ignored next to a gradient');
      return (decoration.gradient! as LinearGradient).colors;
    }

    void show(CoverPalette? palette) =>
        (container.read(appCoverPaletteProvider.notifier) as _Palette).show(
          palette,
        );

    const red = CoverPalette(
      seed: Color(0xFFCC0000),
      colors: [Color(0xFFCC0000), Color(0xFF0000CC)],
    );

    testWidgets('without colors it is the bare surface', (tester) async {
      await pump(tester);
      expect(gradient(tester).every((stop) => stop.a == 0), isTrue);
    });

    testWidgets('cover colors fade in over 300 ms', (tester) async {
      await pump(tester);
      final surface = gradient(tester).first;
      show(red);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final halfway = gradient(tester).first;
      expect(halfway, isNot(surface));
      await tester.pump(const Duration(milliseconds: 200));
      final end = gradient(tester).first;
      expect(end, isNot(halfway));
      expect(end.r, greaterThan(end.b), reason: 'tinted red first');
      expect(end.a, greaterThan(0));
      await tester.pumpAndSettle();
      expect(gradient(tester).first, end);
    });

    testWidgets('still fades when the app theme changes at once', (
      tester,
    ) async {
      container = ProviderContainer(
        overrides: [appCoverPaletteProvider.overrideWith(_Palette.new)],
      );
      addTearDown(container.dispose);
      // Like KanaruApp: the theme follows the cover's seed, with no
      // theme animation.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final seed = ref.watch(
                appCoverPaletteProvider.select((p) => p?.seed),
              );
              return MaterialApp(
                themeAnimationDuration: Duration.zero,
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: seed ?? Colors.blue,
                  ),
                ),
                home: const CoverTintBackground(child: SizedBox.expand()),
              );
            },
          ),
        ),
      );
      final first = gradient(tester).first;
      show(red);
      await tester.pump();
      final start = gradient(tester).first;
      await tester.pump(const Duration(milliseconds: 150));
      final halfway = gradient(tester).first;
      await tester.pump(const Duration(milliseconds: 200));
      final end = gradient(tester).first;
      expect(halfway, isNot(start), reason: 'the tint is still moving');
      expect(end, isNot(halfway));
      expect(end, isNot(first));
    });

    testWidgets('a light/dark switch starts at the new stops, no fade', (
      tester,
    ) async {
      container = ProviderContainer(
        overrides: [appCoverPaletteProvider.overrideWith(_Palette.new)],
      );
      addTearDown(container.dispose);
      final mode = ValueNotifier(ThemeMode.light);
      addTearDown(mode.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ValueListenableBuilder(
            valueListenable: mode,
            builder: (context, mode, _) => MaterialApp(
              themeAnimationDuration: Duration.zero,
              themeMode: mode,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blue,
                  brightness: Brightness.dark,
                ),
              ),
              home: const CoverTintBackground(child: SizedBox.expand()),
            ),
          ),
        ),
      );
      show(red);
      await tester.pumpAndSettle();
      final light = gradient(tester).first;
      mode.value = ThemeMode.dark;
      await tester.pump();
      final atOnce = gradient(tester).first;
      await tester.pump(const Duration(milliseconds: 300));
      expect(gradient(tester).first, atOnce, reason: 'no fade from light');
      expect(atOnce, isNot(light), reason: 'dark has its own stops');
    });

    testWidgets('reduced motion switches on the next frame', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pump(tester);
      final surface = gradient(tester).first;
      show(red);
      await tester.pump();
      await tester.pump();
      final end = gradient(tester).first;
      expect(end, isNot(surface));
      await tester.pump(const Duration(milliseconds: 300));
      expect(gradient(tester).first, end);
    });

    testWidgets('a gray cover still tints the page', (tester) async {
      await pump(tester);
      final surface = gradient(tester).first;
      show(
        const CoverPalette(
          seed: null,
          colors: [Color(0xFF606060), Color(0xFF202020)],
        ),
      );
      await tester.pumpAndSettle();
      expect(gradient(tester).first, isNot(surface));
    });
  });
}
