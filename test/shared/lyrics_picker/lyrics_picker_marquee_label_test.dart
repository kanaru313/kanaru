import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_marquee_label.dart';

const _boxWidth = 120.0;
const _long = 'A very long lyrics source name that cannot fit';
const _style = TextStyle(fontSize: 14);

Widget _host({
  required String text,
  required bool active,
  bool disableAnimations = false,
  double textScale = 1,
  double boxWidth = _boxWidth,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Center(
            child: SizedBox(
              width: boxWidth,
              child: LyricsPickerMarqueeLabel(
                text: text,
                style: _style,
                active: active,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final _label = find.byType(LyricsPickerMarqueeLabel);
Finder get _transforms =>
    find.descendant(of: _label, matching: find.byType(Transform));
Finder get _shader =>
    find.descendant(of: _label, matching: find.byType(ShaderMask));

double _translation(WidgetTester tester) =>
    tester.widget<Transform>(_transforms).transform.getTranslation().x;

double _paintedRight(WidgetTester tester) => tester
    .getRect(find.descendant(of: _label, matching: find.byType(RichText)))
    .right;

double _fadeStart(WidgetTester tester) => tester.getRect(_shader).right - 20;

/// Full text width at the given scale, measured the same way the widget does
/// (inheriting the ambient default text style).
double _textWidth(WidgetTester tester, double scale) {
  final base = DefaultTextStyle.of(tester.element(_label)).style;
  final painter = TextPainter(
    text: TextSpan(text: _long, style: base.merge(_style)),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(scale),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Lets the start delay elapse and the ticker take its first frame, then runs
/// long enough for the eased progress to reach its end hold.
Future<void> _pumpToMaxShift(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 5500));
}

void main() {
  testWidgets('text that fits is plain, unfaded and idle', (tester) async {
    await tester.pumpWidget(_host(text: 'Short', active: true));
    await tester.pumpAndSettle();

    expect(_shader, findsNothing);
    expect(_transforms, findsNothing);
    expect(find.text('Short'), findsOneWidget);
  });

  testWidgets('long text inactive is faded but never moves', (tester) async {
    await tester.pumpWidget(_host(text: _long, active: false));
    await tester.pump(const Duration(seconds: 3));

    expect(_shader, findsOneWidget);
    expect(_translation(tester), 0);
  });

  testWidgets('long text active waits, then scrolls to the measured end', (
    tester,
  ) async {
    await tester.pumpWidget(_host(text: _long, active: true));
    await tester.pump(const Duration(milliseconds: 900));
    expect(_translation(tester), 0);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_translation(tester), lessThan(0));

    await tester.pump(const Duration(milliseconds: 4400));
    final expected = -(_textWidth(tester, 1) + 20 - _boxWidth);
    expect(_translation(tester), closeTo(expected, 0.5));

    // The test font draws glyphs 1 em wide, so the painted text ends exactly
    // where the fade begins.
    expect(_paintedRight(tester), closeTo(_fadeStart(tester), 0.5));
  });

  for (final width in [160.0, 300.0]) {
    testWidgets('last glyph ends where the fade starts in a $width px box', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(text: _long, active: true, boxWidth: width),
      );
      await _pumpToMaxShift(tester);

      expect(_paintedRight(tester), closeTo(_fadeStart(tester), 0.5));
    });
  }

  testWidgets('changing the text while active restarts from the start', (
    tester,
  ) async {
    await tester.pumpWidget(_host(text: _long, active: true));
    await _pumpToMaxShift(tester);
    expect(_translation(tester), lessThan(-100));

    await tester.pumpWidget(_host(text: '$_long, edited', active: true));
    expect(_translation(tester), 0);
    await tester.pump(const Duration(milliseconds: 900));
    expect(_translation(tester), 0);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_translation(tester), lessThan(0));
  });

  testWidgets('going inactive returns to the start and stops the ticker', (
    tester,
  ) async {
    await tester.pumpWidget(_host(text: _long, active: true));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(_translation(tester), lessThan(0));

    await tester.pumpWidget(_host(text: _long, active: false));
    expect(_translation(tester), 0);
    await tester.pumpAndSettle();
  });

  testWidgets('going inactive during the pause cancels the start', (
    tester,
  ) async {
    await tester.pumpWidget(_host(text: _long, active: true));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(_host(text: _long, active: false));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(_translation(tester), 0);
  });

  testWidgets('disposing while active leaves no timer or ticker', (
    tester,
  ) async {
    await tester.pumpWidget(_host(text: _long, active: true));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('animations disabled: static ellipsis, no fade, no motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(text: _long, active: true, disableAnimations: true),
    );
    await tester.pump(const Duration(seconds: 8));

    expect(_shader, findsNothing);
    expect(_transforms, findsNothing);
    final text = tester.widget<Text>(
      find.descendant(of: _label, matching: find.byType(Text)),
    );
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
  });

  testWidgets('larger text scale lengthens the measured shift', (tester) async {
    await tester.pumpWidget(_host(text: _long, active: true));
    await _pumpToMaxShift(tester);
    final normal = _translation(tester);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host(text: _long, active: true, textScale: 1.5));
    await _pumpToMaxShift(tester);
    final scaled = _translation(tester);

    expect(scaled, lessThan(normal));
    expect(scaled, closeTo(-(_textWidth(tester, 1.5) + 20 - _boxWidth), 0.5));
  });
}
