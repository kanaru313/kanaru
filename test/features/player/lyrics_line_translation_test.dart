import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/settings/translation_prefs.dart';
import 'package:kanaru/features/player/lyrics/lyrics_line.dart';
import 'package:kanaru/features/player/lyrics/translation/lyrics_translation_placeholder.dart';
import 'package:kanaru/features/player/lyrics/translation/translated_line_text.dart';
import 'package:material_ui/material_ui.dart';

const _longTranslation =
    'A translation long enough that it has to wrap onto several lines in a '
    'narrow column, to prove wrapping does not depend on the current line';

void main() {
  late ValueNotifier<bool> current;

  Future<void> pump(
    WidgetTester tester, {
    String original = 'Hello',
    String? translation,
    bool pending = false,
    LyricsTranslationDisplay display = LyricsTranslationDisplay.underLine,
    TextDirection? direction,
    Animation<double>? pulse,
  }) async {
    current = ValueNotifier(false);
    addTearDown(current.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: LyricsLine(
              line: LyricLine(Duration.zero, original),
              current: current,
              onTap: () {},
              translation: translation,
              translationPending: pending,
              display: display,
              translationDirection: direction,
              pulse: pulse,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextStyle styleOf(WidgetTester tester, String text) => tester
      .widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      )
      .style;

  Future<void> flip(WidgetTester tester) async {
    current.value = !current.value;
    await tester.pumpAndSettle();
  }

  testWidgets('under: the translation keeps its size when the line turns '
      'current, even when it wraps', (tester) async {
    await pump(tester, translation: _longTranslation);
    final translation = find.text(_longTranslation);
    final before = tester.getSize(translation);
    expect(
      before.height,
      greaterThan(styleOf(tester, _longTranslation).fontSize! * 2),
    );
    await flip(tester);
    expect(tester.getSize(translation), before);
    await flip(tester);
    expect(tester.getSize(translation), before);
  });

  testWidgets(
    'under: the whole line keeps its size for a main line that fits',
    (tester) async {
      await pump(tester, translation: 'Xin chào');
      final line = find.byType(LyricsLine);
      final before = tester.getSize(line);
      await flip(tester);
      expect(tester.getSize(line), before);
    },
  );

  testWidgets('under: the translation is smaller and dimmer than the line', (
    tester,
  ) async {
    await pump(tester, translation: 'Xin chào');
    final main = styleOf(tester, 'Hello');
    final added = styleOf(tester, 'Xin chào');
    expect(added.fontSize, closeTo(main.fontSize! * 0.62, 0.01));
    expect(added.fontWeight, FontWeight.w400);
    final dim = added.color!.a;
    await flip(tester);
    expect(styleOf(tester, 'Xin chào').color!.a, greaterThan(dim));
    expect(styleOf(tester, 'Xin chào').fontWeight, FontWeight.w400);
  });

  testWidgets('replace: the translation is the main line, the original small '
      'and fixed in size', (tester) async {
    await pump(
      tester,
      translation: _longTranslation,
      display: LyricsTranslationDisplay.replace,
    );
    final big = styleOf(tester, _longTranslation).fontSize!;
    final small = styleOf(tester, 'Hello').fontSize!;
    expect(small, closeTo(big * 0.5, 0.01));
    final before = tester.getSize(find.text('Hello'));
    await flip(tester);
    expect(tester.getSize(find.text('Hello')), before);
    // The main line keeps the usual weight switch.
    expect(styleOf(tester, _longTranslation).fontWeight, FontWeight.w700);
  });

  testWidgets('replace: a line without a translation is the main line alone', (
    tester,
  ) async {
    await pump(tester, display: LyricsTranslationDisplay.replace);
    final main = Theme.of(tester.element(find.byType(LyricsLine)))
        .textTheme
        .headlineSmall!
        .fontSize;
    expect(styleOf(tester, 'Hello').fontSize, main);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('pending: one bar under the line in a fade, no custom paint', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);
    await pump(tester, pending: true, pulse: controller);
    final bar = find.byType(LyricsTranslationPlaceholder);
    expect(bar, findsOneWidget);
    expect(
      find.descendant(of: bar, matching: find.byType(FadeTransition)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar, matching: find.byType(CustomPaint)),
      findsNothing,
    );
    // 0.55 em per character of "Hello" at the translation size.
    final size = styleOf(tester, 'Hello').fontSize! * 0.62;
    expect(
      tester
          .getSize(
            find.descendant(of: bar, matching: find.byType(SizedBox)).first,
          )
          .width,
      closeTo(size * 0.55 * 5, 0.5),
    );
  });

  testWidgets('pending without a pulse draws a still bar', (tester) async {
    await pump(tester, pending: true);
    expect(find.byType(LyricsTranslationPlaceholder), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LyricsTranslationPlaceholder),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('a blank line has neither translation nor bar', (tester) async {
    await pump(tester, original: '', pending: true);
    expect(find.byType(LyricsTranslationPlaceholder), findsNothing);
  });

  testWidgets('the translation takes the given text direction', (tester) async {
    await pump(tester, translation: 'مرحبا', direction: TextDirection.rtl);
    expect(
      tester.widget<Text>(find.text('مرحبا')).textDirection,
      TextDirection.rtl,
    );
    expect(tester.widget<Text>(find.text('Hello')).textDirection, isNull);
  });

  testWidgets('one semantics label reads the original and the translation', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, translation: 'Xin chào');
    expect(find.bySemanticsLabel('Hello, Xin chào'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('without a translation the line is the plain text', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(Text), findsOneWidget);
    expect(find.byType(Column), findsNothing);
  });

  test('right-to-left languages read right to left', () {
    for (final code in ['ar', 'he', 'fa']) {
      expect(translationDirectionOf(code), TextDirection.rtl, reason: code);
    }
    for (final code in ['vi', 'en', 'ja']) {
      expect(translationDirectionOf(code), TextDirection.ltr, reason: code);
    }
  });
}
