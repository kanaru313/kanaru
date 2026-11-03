import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/theme.dart';
import 'package:material_color_utilities/material_color_utilities.dart'
    show Cam16, Hct;
import 'package:material_ui/material_ui.dart';

double _dist(Color a, Color b) =>
    Cam16.fromInt(a.toARGB32()).distance(Cam16.fromInt(b.toARGB32()));

double _contrast(Color a, Color b) {
  final la = a.computeLuminance() + 0.05;
  final lb = b.computeLuminance() + 0.05;
  return la > lb ? la / lb : lb / la;
}

ColorScheme _theme(
  ColorScheme? dynamicScheme,
  Brightness brightness, {
  Color? coverSeed,
}) => buildTheme(
  dynamicScheme,
  brightness,
  coverSeed: coverSeed,
  fontFamily: 'Inter',
).colorScheme;

ColorScheme _seed(Color seed, Brightness b) =>
    ColorScheme.fromSeed(seedColor: seed, brightness: b);

void main() {
  const red = Color(0xFFC62828);
  const blue = Color(0xFF1E88E5);

  group('fallback dark', () {
    final plain = _seed(kanaruSeedColor, Brightness.dark);
    final scheme = _theme(null, Brightness.dark);

    test('error is apart from primary, tone 65, same hue', () {
      expect(scheme.error, isNot(plain.error));
      expect(_dist(scheme.primary, scheme.error), greaterThanOrEqualTo(7));
      final hct = Hct.fromInt(scheme.error.toARGB32());
      expect(hct.tone, closeTo(65, 1));
      final hue = Hct.fromInt(plain.error.toARGB32()).hue;
      expect((hct.hue - hue).abs(), lessThan(2));
    });

    test('other roles keep the Material 3 values', () {
      expect(scheme.primary, plain.primary);
      expect(scheme.onError, plain.onError);
      expect(scheme.errorContainer, plain.errorContainer);
      expect(scheme.onErrorContainer, plain.onErrorContainer);
    });

    test('error is readable', () {
      expect(
        _contrast(scheme.error, scheme.onError),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.error, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  test('fallback light keeps the Material 3 error', () {
    expect(
      _theme(null, Brightness.light).error,
      _seed(kanaruSeedColor, Brightness.light).error,
    );
  });

  test('red cover seed in dark gets a distinct error', () {
    final scheme = _theme(null, Brightness.dark, coverSeed: red);
    expect(_dist(scheme.primary, scheme.error), greaterThanOrEqualTo(7));
  });

  test('red dynamic accent in dark gets a distinct error', () {
    final dynamic = _seed(red, Brightness.dark);
    final scheme = _theme(dynamic, Brightness.dark);
    expect(_dist(scheme.primary, scheme.error), greaterThanOrEqualTo(7));
  });

  group('non-colliding schemes keep the Material 3 error', () {
    test('blue cover seed, dark', () {
      expect(
        _theme(null, Brightness.dark, coverSeed: blue).error,
        _seed(blue, Brightness.dark).error,
      );
    });
    test('blue cover seed, light', () {
      expect(
        _theme(null, Brightness.light, coverSeed: blue).error,
        _seed(blue, Brightness.light).error,
      );
    });
    test('blue dynamic accent, dark', () {
      final dynamic = _seed(blue, Brightness.dark);
      expect(
        _theme(dynamic, Brightness.dark).error,
        dynamic.harmonized().error,
      );
    });
  });

  group('sweep over cover seeds', () {
    Iterable<(String, Color)> seeds() sync* {
      for (var hue = 0; hue < 360; hue += 3) {
        for (final chroma in [30.0, 60.0, 90.0]) {
          final argb = Hct.from(hue.toDouble(), chroma, 50).toInt();
          yield ('hue $hue chroma $chroma tone 50', Color(argb));
        }
      }
    }

    test('dark: error stays apart from primary', () {
      for (final (name, seed) in seeds()) {
        final scheme = _theme(null, Brightness.dark, coverSeed: seed);
        final d = _dist(scheme.primary, scheme.error);
        expect(d, greaterThanOrEqualTo(7), reason: 'seed $name: $d');
      }
    });

    test('light: Material 3 error is already apart from primary', () {
      for (final (name, seed) in seeds()) {
        final scheme = _theme(null, Brightness.light, coverSeed: seed);
        final d = _dist(scheme.primary, scheme.error);
        expect(d, greaterThanOrEqualTo(7), reason: 'seed $name: $d');
      }
    });
  });
}
