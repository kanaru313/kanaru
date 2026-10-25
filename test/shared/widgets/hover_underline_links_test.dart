import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/hover_underline_links.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Widget child, {double width = 400}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  ),
);

/// Link, plain ' & ', link, plain ' / ', link.
Widget _three(List<String> log, {List<Offset>? positions}) {
  void tap(String name, Offset p) {
    log.add(name);
    positions?.add(p);
  }

  return _host(
    HoverUnderlineLinks(
      segments: [
        LinkSegment('Ann', onTap: (p) => tap('Ann', p)),
        const LinkSegment(' & '),
        LinkSegment('Bob', onTap: (p) => tap('Bob', p)),
        const LinkSegment(' / '),
        LinkSegment('Cy', onTap: (p) => tap('Cy', p)),
      ],
    ),
  );
}

/// Underline flag of each child span of the line's root span.
List<bool> _underlines(WidgetTester tester) {
  final richText = tester.widget<RichText>(
    find.descendant(
      of: find.byType(HoverUnderlineLinks),
      matching: find.byType(RichText),
    ),
  );
  // Text.rich wraps the line's own root span in one more span.
  final root = (richText.text as TextSpan).children!.single as TextSpan;
  return [
    for (final child in root.children!.cast<TextSpan>())
      child.style?.decoration == TextDecoration.underline,
  ];
}

List<TextSpan> _spans(WidgetTester tester) {
  final richText = tester.widget<RichText>(
    find.descendant(
      of: find.byType(HoverUnderlineLinks),
      matching: find.byType(RichText),
    ),
  );
  final root = (richText.text as TextSpan).children!.single as TextSpan;
  return root.children!.cast<TextSpan>();
}

/// Global rect of the first occurrence of [s] in the line's paragraph.
Rect _rect(WidgetTester tester, String s) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(
      of: find.byType(HoverUnderlineLinks),
      matching: find.byType(RichText),
    ),
  );
  final start = paragraph.text.toPlainText().indexOf(s);
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + s.length),
      )
      .first;
  return box.toRect().shift(paragraph.localToGlobal(Offset.zero));
}

Offset _center(WidgetTester tester, String s) => _rect(tester, s).center;

Future<void> _tapText(WidgetTester tester, String s) =>
    tester.tapAt(_center(tester, s));

Future<TestGesture> _mouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: const Offset(1000, 1000));
  addTearDown(gesture.removePointer);
  await tester.pump();
  return gesture;
}

void main() {
  testWidgets('tapping a link passes a position inside its text', (
    tester,
  ) async {
    final log = <String>[];
    final positions = <Offset>[];
    await tester.pumpWidget(_three(log, positions: positions));
    final rect = _rect(tester, 'Bob');
    await _tapText(tester, 'Bob');
    expect(log, ['Bob']);
    expect(rect.contains(positions.single), isTrue);
  });

  testWidgets('tapping a separator does nothing', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_three(log));
    await _tapText(tester, ' & ');
    expect(log, isEmpty);
  });

  testWidgets('hover underlines only the hovered link', (tester) async {
    await tester.pumpWidget(_three([]));
    final mouse = await _mouse(tester);
    expect(_underlines(tester), [false, false, false, false, false]);

    await mouse.moveTo(_center(tester, 'Bob'));
    await tester.pump();
    expect(_underlines(tester), [false, false, true, false, false]);

    await mouse.moveTo(_center(tester, ' & '));
    await tester.pump();
    expect(_underlines(tester), [false, false, false, false, false]);

    await mouse.moveTo(_center(tester, 'Ann'));
    await tester.pump();
    expect(_underlines(tester), [true, false, false, false, false]);

    await mouse.moveTo(const Offset(1000, 1000));
    await tester.pump();
    expect(_underlines(tester), [false, false, false, false, false]);
  });

  testWidgets('cursor is click over a link, not over a separator', (
    tester,
  ) async {
    await tester.pumpWidget(_three([]));
    final mouse = await _mouse(tester);
    final tracker = RendererBinding.instance.mouseTracker;

    await mouse.moveTo(_center(tester, 'Ann'));
    await tester.pump();
    expect(tracker.debugDeviceActiveCursor(1), SystemMouseCursors.click);

    await mouse.moveTo(_center(tester, ' & '));
    await tester.pump();
    expect(tracker.debugDeviceActiveCursor(1), isNot(SystemMouseCursors.click));
  });

  testWidgets('hover settles without a rebuild loop', (tester) async {
    await tester.pumpWidget(_three([]));
    final mouse = await _mouse(tester);
    await mouse.moveTo(_center(tester, 'Ann'));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('disposing while hovered raises no error', (tester) async {
    await tester.pumpWidget(_three([]));
    final mouse = await _mouse(tester);
    await mouse.moveTo(_center(tester, 'Ann'));
    await tester.pump();

    await tester.pumpWidget(_host(const SizedBox()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard focus underlines every link, Enter runs the first', (
    tester,
  ) async {
    final log = <String>[];
    final positions = <Offset>[];
    await tester.pumpWidget(_three(log, positions: positions));
    expect(_underlines(tester), [false, false, false, false, false]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_underlines(tester), [true, false, true, false, true]);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(log, ['Ann']);
    final box = tester.getRect(find.byType(HoverUnderlineLinks));
    expect(positions.single, box.bottomLeft);
  });

  testWidgets('Enter runs onActivate instead of a link when given', (
    tester,
  ) async {
    final log = <String>[];
    final activated = <Offset>[];
    await tester.pumpWidget(
      _host(
        HoverUnderlineLinks(
          onActivate: activated.add,
          segments: [
            LinkSegment('Ann', onTap: (_) => log.add('Ann')),
            const LinkSegment(' & '),
            LinkSegment('Bob', onTap: (_) => log.add('Bob')),
          ],
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(log, isEmpty);
    final box = tester.getRect(find.byType(HoverUnderlineLinks));
    expect(activated, [box.bottomLeft]);
  });

  testWidgets('plain-only segments have no focus stop', (tester) async {
    await tester.pumpWidget(
      _host(const HoverUnderlineLinks(segments: [LinkSegment('Just text')])),
    );
    expect(find.byType(FocusableActionDetector), findsNothing);
    expect(find.text('Just text'), findsOneWidget);
  });

  testWidgets('link spans expose isLink and a tap action', (tester) async {
    final handle = tester.ensureSemantics();
    final log = <String>[];
    await tester.pumpWidget(_three(log));

    final node = find.semantics.byLabel('Bob').evaluate().single;
    expect(node.flagsCollection.isLink, isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    // The test binding's own owner holds the semantics tree; the root owner
    // does not.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.tap,
    );
    await tester.pump();
    expect(log, ['Bob']);
    handle.dispose();
  });

  testWidgets('a swap between pointer down and up runs the pressed link', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(_three(log));
    final at = _center(tester, 'Ann');
    final gesture = await tester.startGesture(at);

    await tester.pumpWidget(
      _host(
        HoverUnderlineLinks(
          segments: [
            LinkSegment('Ann', onTap: (_) => log.add('new-Ann')),
            LinkSegment('Zed', onTap: (_) => log.add('Zed')),
          ],
        ),
      ),
    );
    await gesture.up();
    await tester.pump();
    expect(log, ['Ann']);
  });

  testWidgets('new segments replace callbacks and drop surplus recognizers', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(_three(log));
    await tester.pumpWidget(
      _host(
        HoverUnderlineLinks(
          segments: [LinkSegment('Only', onTap: (_) => log.add('Only'))],
        ),
      ),
    );
    await _tapText(tester, 'Only');
    expect(log, ['Only']);

    await tester.pumpWidget(
      _host(
        HoverUnderlineLinks(
          segments: [
            const LinkSegment('Only'),
            LinkSegment(' x ', onTap: (_) => log.add('x')),
          ],
        ),
      ),
    );
    await _tapText(tester, 'Only');
    await _tapText(tester, ' x ');
    expect(log, ['Only', 'x']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the pressed link drops its captured callback', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final log = <String>[];
    await tester.pumpWidget(_three(log));
    final gesture = await tester.startGesture(_center(tester, 'Bob'));

    await tester.pumpWidget(
      _host(
        HoverUnderlineLinks(
          segments: [
            LinkSegment('Ann', onTap: (_) => log.add('Ann')),
            LinkSegment(' & ', onTap: (_) => log.add('new')),
          ],
        ),
      ),
    );
    await gesture.up();
    await tester.pump();
    expect(log, isEmpty);

    final node = find.semantics.byLabel(' & ').evaluate().single;
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.tap,
    );
    await tester.pump();
    expect(log, ['new']);
    handle.dispose();
  });

  testWidgets('long text keeps one line with an ellipsis', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      _host(
        HoverUnderlineLinks(
          segments: [
            LinkSegment('A very long artist name', onTap: (_) => log.add('a')),
            const LinkSegment(' feat. '),
            LinkSegment('Another long one', onTap: (_) => log.add('b')),
          ],
        ),
        width: 60,
      ),
    );
    final richText = tester.widget<RichText>(find.byType(RichText).last);
    expect(richText.maxLines, 1);
    expect(richText.overflow, TextOverflow.ellipsis);

    await tester.tapAt(
      tester.getTopLeft(find.byType(HoverUnderlineLinks)) + const Offset(5, 5),
    );
    expect(log, ['a']);
  });

  testWidgets('all spans carry the shadow, only the hovered link underlines', (
    tester,
  ) async {
    await tester.pumpWidget(_three([]));
    final mouse = await _mouse(tester);
    await mouse.moveTo(_center(tester, 'Bob'));
    await tester.pump();

    final context = tester.element(find.byType(HoverUnderlineLinks));
    final original =
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurface;
    final spans = _spans(tester);
    for (final span in spans) {
      final style = span.style!;
      expect(style.color, const Color(0x00000000));
      expect(style.shadows, hasLength(1));
      expect(style.shadows!.single.color, original);
      expect(style.shadows!.single.offset, const Offset(0, -3));
    }
    for (final i in [0, 1, 3, 4]) {
      expect(spans[i].style!.decoration, isNull);
    }
    expect(spans[2].style!.decoration, TextDecoration.underline);
    expect(spans[2].style!.decorationColor, original);
  });

  testWidgets(
    'the text is translated (paint only) by the gap to cancel the shadow',
    (tester) async {
      await tester.pumpWidget(_three([]));
      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(HoverUnderlineLinks),
          matching: find.byType(Transform),
        ),
      );
      expect(transform.transform.getTranslation().y, 3);
      expect(transform.transform.getTranslation().x, 0);
      expect(transform.transformHitTests, isFalse);
    },
  );

  testWidgets('top and bottom rows of the glyph box hit the link', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(_three(log));
    // `_rect` is in painted coordinates; hit-testing is not translated, so
    // the glyph box in hit-test coordinates is the layout box of the glyphs.
    final glyphs = _rect(tester, 'Bob').shift(const Offset(0, -3));
    final x = glyphs.center.dx;
    final mouse = await _mouse(tester);
    for (final y in [glyphs.top + 0.5, glyphs.bottom - 0.5]) {
      await mouse.moveTo(Offset(x, y));
      await tester.pump();
      expect(_underlines(tester)[2], isTrue, reason: 'hover at y=$y');
      await tester.tapAt(Offset(x, y));
      await tester.pump();
    }
    expect(log, ['Bob', 'Bob']);
    // Just outside the glyph box is a miss.
    await mouse.moveTo(Offset(x, glyphs.top - 0.5));
    await tester.pump();
    expect(_underlines(tester)[2], isFalse);
  });

  testWidgets('hover does not change the paragraph size', (tester) async {
    await tester.pumpWidget(_three([]));
    final mouse = await _mouse(tester);
    final paragraph = find.descendant(
      of: find.byType(HoverUnderlineLinks),
      matching: find.byType(RichText),
    );
    final before = tester.getSize(paragraph);
    final topBefore = tester.getTopLeft(paragraph);
    await mouse.moveTo(_center(tester, 'Bob'));
    await tester.pump();
    expect(_underlines(tester)[2], isTrue);
    expect(tester.getSize(paragraph), before);
    expect(tester.getTopLeft(paragraph), topBefore);
  });
}
