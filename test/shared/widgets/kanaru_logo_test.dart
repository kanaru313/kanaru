import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/kanaru_logo.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Widget child, {Color seed = Colors.teal}) => MaterialApp(
  theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed)),
  home: Center(child: child),
);

KanaruLogoPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(KanaruLogo),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as KanaruLogoPainter;
}

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 0.01));
  expect(actual.top, closeTo(expected.top, 0.01));
  expect(actual.right, closeTo(expected.right, 0.01));
  expect(actual.bottom, closeTo(expected.bottom, 0.01));
}

void main() {
  testWidgets('takes a square of the given size', (tester) async {
    await tester.pumpWidget(_host(const KanaruLogo(size: 40)));
    expect(tester.getSize(find.byType(KanaruLogo)), const Size(40, 40));
  });

  test('colors are the fixed icon colors', () {
    expect(KanaruLogoColors.background, const Color(0xFF1B1F2A));
    expect(KanaruLogoColors.stem, const Color(0xFFFFFFFF));
    expect(KanaruLogoColors.wedge, const Color(0xFFFFB4A2));
  });

  testWidgets('does not change with the theme', (tester) async {
    await tester.pumpWidget(_host(const KanaruLogo()));
    final teal = _painter(tester);
    await tester.pumpWidget(_host(const KanaruLogo(), seed: Colors.red));
    expect(_painter(tester), same(teal));
    expect(teal.shouldRepaint(const KanaruLogoPainter()), isFalse);
  });

  test('background is the full rounded square', () {
    _expectRect(
      kanaruLogoBackground(128).getBounds(),
      const Rect.fromLTRB(0, 0, 128, 128),
    );
    final path = kanaruLogoBackground(128);
    expect(path.contains(const Offset(1, 1)), isFalse);
    expect(path.contains(const Offset(64, 64)), isTrue);
    expect(kanaruLogoBackground(64).contains(const Offset(0.5, 0.5)), isFalse);
  });

  test('stem bounds follow the SVG and scale with size', () {
    _expectRect(
      kanaruLogoStem(128).getBounds(),
      const Rect.fromLTRB(30, 28, 46, 100),
    );
    _expectRect(
      kanaruLogoStem(64).getBounds(),
      const Rect.fromLTRB(15, 14, 23, 50),
    );
  });

  test('wedge has the notch, interior and rounded corners', () {
    final wedge = kanaruLogoWedge(128);
    final stem = kanaruLogoStem(128);
    expect(wedge.contains(const Offset(80, 64)), isTrue);
    expect(wedge.contains(const Offset(49, 64)), isFalse);
    expect(stem.contains(const Offset(49, 64)), isFalse);
    // Square corners would contain these points; the arcs round them off.
    expect(wedge.contains(const Offset(99.5, 31.5)), isFalse);
    expect(wedge.contains(const Offset(99.5, 96.5)), isFalse);
    expect(wedge.contains(const Offset(99, 40)), isTrue);
    final bounds = wedge.getBounds();
    expect(bounds.right, closeTo(100, 0.01));
    // Probes inside each arc's bulge: a flipped arc direction misses them.
    expect(wedge.contains(const Offset(97, 32)), isTrue);
    expect(wedge.contains(const Offset(97, 96)), isTrue);
    expect(wedge.contains(const Offset(50.5, 64)), isTrue);
    // The left arc bulges to x = 50.0 (getBounds is control-point loose).
    expect(wedge.contains(const Offset(50.2, 64)), isTrue);
    expect(wedge.contains(const Offset(49.8, 64)), isFalse);
  });

  test('geometry and colors match the scalable SVG icon', () {
    final svg = File(
      'packaging/linux/icons/hicolor/scalable/apps/'
      'io.github.kanaru313.kanaru.svg',
    ).readAsStringSync();
    for (final literal in [
      'rx="30"',
      'fill="#1B1F2A"',
      'x="30" y="28" width="16" height="72" rx="8"',
      'fill="#FFFFFF"',
      'd="M52.441 59.169 L90.441 31.169 A6 6 0 0 1 100 36 L100 92 '
          'A6 6 0 0 1 90.441 96.831 L52.441 68.831 '
          'A6 6 0 0 1 52.441 59.169 Z"',
      'fill="#FFB4A2"',
    ]) {
      expect(svg, contains(literal));
    }
    expect(KanaruLogoColors.background, const Color(0xFF1B1F2A));
    expect(KanaruLogoColors.stem, const Color(0xFFFFFFFF));
    expect(KanaruLogoColors.wedge, const Color(0xFFFFB4A2));
  });

  testWidgets('announces the label when given, else is excluded', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const KanaruLogo(semanticLabel: 'Kanaru')));
    expect(find.bySemanticsLabel('Kanaru'), findsOneWidget);

    await tester.pumpWidget(_host(const KanaruLogo()));
    expect(find.bySemanticsLabel('Kanaru'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(KanaruLogo),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
  });
}
