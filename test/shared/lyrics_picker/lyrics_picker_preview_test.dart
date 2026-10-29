import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_preview.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';

Future<void> _pump(
  WidgetTester tester,
  LyricsBody body, {
  double width = 400,
}) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: LyricsPickerPreview(candidate: fakeCandidate(body: body)),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('synced lyrics show each start time and the text', (
    tester,
  ) async {
    await _pump(
      tester,
      const LyricsBody(syncedLrc: '[00:29.20] hello\n[01:05.07] world'),
    );

    expect(find.text('00:29.20'), findsOneWidget);
    expect(find.text('01:05.07'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('world'), findsOneWidget);
  });

  testWidgets('plain lyrics show no time', (tester) async {
    await _pump(tester, const LyricsBody(plain: 'one\ntwo'));

    expect(find.text('one'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d\d:\d\d')), findsNothing);
  });

  testWidgets('synced text that does not parse shows the plain text only', (
    tester,
  ) async {
    await _pump(
      tester,
      const LyricsBody(syncedLrc: '[ar:x]', plain: 'only plain'),
    );

    expect(find.text('only plain'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d\d:\d\d')), findsNothing);
  });

  testWidgets('an empty synced line keeps its time with a dim note', (
    tester,
  ) async {
    await _pump(
      tester,
      const LyricsBody(syncedLrc: '[00:01.00] hello\n[00:10.50]\n[00:12.00] x'),
    );

    expect(find.text('00:10.50'), findsOneWidget);
    expect(find.text('♪'), findsOneWidget);
  });

  testWidgets('a song of an hour or more widens the time to h:mm:ss.xx', (
    tester,
  ) async {
    await _pump(
      tester,
      const LyricsBody(syncedLrc: '[00:05.00] a\n[61:02.30] b'),
    );

    expect(find.text('0:00:05.00'), findsOneWidget);
    expect(find.text('1:01:02.30'), findsOneWidget);
  });

  for (final (name, lrc, times) in [
    ('mm:ss.xx', '[00:29.20] a\n[10:05.07] b', ['00:29.20', '10:05.07']),
    ('h:mm:ss.xx', '[00:05.00] a\n[61:02.30] b', ['0:00:05.00', '1:01:02.30']),
  ]) {
    testWidgets('a $name time sits on one line inside the column', (
      tester,
    ) async {
      await _pump(tester, LyricsBody(syncedLrc: lrc), width: 300);

      for (final t in times) {
        final finder = find.text(t);
        final style = tester.widget<Text>(finder).style!;
        final painter = TextPainter(
          text: TextSpan(text: t, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        final column = tester.getRect(
          find.ancestor(of: finder, matching: find.byType(SizedBox)).first,
        );
        final rect = tester.getRect(finder);
        expect(rect.height, closeTo(painter.height, 0.5));
        expect(column.contains(rect.topLeft), isTrue);
        expect(
          column.contains(rect.bottomRight - const Offset(0.1, 0.1)),
          isTrue,
        );
        painter.dispose();
      }
    });
  }

  testWidgets('a long line wraps under the text, not under the time', (
    tester,
  ) async {
    final long = List.filled(40, 'word').join(' ');
    await _pump(tester, LyricsBody(syncedLrc: '[00:29.20] $long'));

    final time = find.text('00:29.20');
    final text = find.text(long);
    final column = tester.getSize(
      find.ancestor(of: time, matching: find.byType(SizedBox)).first,
    );
    expect(
      tester.getTopLeft(text).dx - tester.getTopLeft(time).dx,
      column.width,
    );
    // It did wrap: taller than one line of the time.
    expect(
      tester.getSize(text).height,
      greaterThan(tester.getSize(time).height * 2),
    );
    expect(tester.takeException(), isNull);
  });
}
