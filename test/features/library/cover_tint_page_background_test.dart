import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/cover_colors/cover_palette.dart';
import 'package:kanaru/core/cover_colors/cover_palette_of_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/library/widgets/cover_tint_page_background.dart';
import 'package:kanaru/shared/readable_gradient_stops.dart';
import 'package:material_ui/material_ui.dart';

const _c1 = CoverPalette(
  seed: Color(0xFFCC0000),
  colors: [Color(0xFFCC0000), Color(0xFF880000)],
);
const _c2 = CoverPalette(
  seed: Color(0xFF00CC00),
  colors: [Color(0xFF00CC00), Color(0xFF008800)],
);
const _c3 = CoverPalette(
  seed: Color(0xFF0000CC),
  colors: [Color(0xFF0000CC), Color(0xFF000088)],
);

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

  /// Pumps the widget; a `null` palette settles without colors, a key in
  /// [pending] never settles until its completer does.
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required Widget Function(Widget child) build,
    Map<String, CoverPalette?> palettes = const {},
    Map<String, Completer<CoverPalette?>> pending = const {},
    bool on = true,
  }) async {
    final container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(display: DisplayPrefs(colorFromCover: on)),
        ),
        for (final e in palettes.entries)
          coverPaletteOfProvider(e.key).overrideWith((ref) async => e.value),
        for (final e in pending.entries)
          coverPaletteOfProvider(e.key).overrideWith((ref) => e.value.future),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: build(const SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  List<Color>? gradient(WidgetTester tester) {
    final boxes = find.descendant(
      of: find.byType(CoverTintPageBackground),
      matching: find.byType(DecoratedBox),
    );
    if (boxes.evaluate().isEmpty) return null;
    final decoration = tester.widget<DecoratedBox>(boxes.first).decoration;
    return ((decoration as BoxDecoration).gradient! as LinearGradient).colors;
  }

  List<Color> stops(List<Color> colors) => readableGradientStops(
    colors,
    surface: scheme.surface,
    onSurface: scheme.onSurface,
    brightness: scheme.brightness,
  );

  Widget blend(Widget child, List<String> keys) =>
      CoverTintPageBackground.blend(coverKeys: keys, child: child);

  testWidgets('setting off watches no palette and paints no tint', (
    tester,
  ) async {
    final container = await pump(
      tester,
      on: false,
      palettes: {'k1': _c1, 'k2': _c2, 'k3': _c3},
      build: (c) => blend(c, ['k1', 'k2', 'k3']),
    );
    expect(gradient(tester), isNull);
    for (final k in ['k1', 'k2', 'k3']) {
      expect(container.exists(coverPaletteOfProvider(k)), isFalse);
    }
  });

  testWidgets('empty key list paints no tint', (tester) async {
    await pump(tester, build: (c) => blend(c, const []));
    expect(gradient(tester), isNull);
  });

  testWidgets('a single cover tints with all of its colors', (tester) async {
    await pump(
      tester,
      palettes: {'k1': _c1},
      build: (c) => CoverTintPageBackground(coverKey: 'k1', child: c),
    );
    expect(gradient(tester), stops(_c1.colors));
  });

  testWidgets('a null cover key paints no tint', (tester) async {
    await pump(
      tester,
      build: (c) => CoverTintPageBackground(coverKey: null, child: c),
    );
    expect(gradient(tester), isNull);
  });

  testWidgets('blend takes the most common color of each cover in order', (
    tester,
  ) async {
    await pump(
      tester,
      palettes: {'k1': _c1, 'k2': _c2, 'k3': _c3},
      build: (c) => blend(c, ['k1', 'k2', 'k3']),
    );
    expect(
      gradient(tester),
      stops([_c1.colors.first, _c2.colors.first, _c3.colors.first]),
    );
  });

  testWidgets('blend waits for every cover, then tints', (tester) async {
    final wait = Completer<CoverPalette?>();
    await pump(
      tester,
      palettes: {'k1': _c1, 'k3': _c3},
      pending: {'k2': wait},
      build: (c) => blend(c, ['k1', 'k2', 'k3']),
    );
    expect(gradient(tester), isNull);
    wait.complete(_c2);
    await tester.pump();
    await tester.pump();
    expect(
      gradient(tester),
      stops([_c1.colors.first, _c2.colors.first, _c3.colors.first]),
    );
  });

  testWidgets('a cover without colors is left out of the blend', (
    tester,
  ) async {
    await pump(
      tester,
      palettes: {'k1': _c1, 'k2': null, 'k3': _c3},
      build: (c) => blend(c, ['k1', 'k2', 'k3']),
    );
    expect(gradient(tester), stops([_c1.colors.first, _c3.colors.first]));
  });

  testWidgets('only one cover with colors gives all of its colors', (
    tester,
  ) async {
    await pump(
      tester,
      palettes: {'k1': null, 'k2': _c2, 'k3': null},
      build: (c) => blend(c, ['k1', 'k2', 'k3']),
    );
    expect(gradient(tester), stops(_c2.colors));
  });

  testWidgets('no cover with colors paints no tint', (tester) async {
    await pump(
      tester,
      palettes: {'k1': null, 'k2': null},
      build: (c) => blend(c, ['k1', 'k2']),
    );
    expect(gradient(tester), isNull);
  });

  testWidgets('only the first four covers are read', (tester) async {
    final container = await pump(
      tester,
      palettes: {for (var i = 1; i <= 5; i++) 'k$i': _c1},
      build: (c) => blend(c, [for (var i = 1; i <= 5; i++) 'k$i']),
    );
    expect(container.exists(coverPaletteOfProvider('k4')), isTrue);
    expect(container.exists(coverPaletteOfProvider('k5')), isFalse);
  });
}
