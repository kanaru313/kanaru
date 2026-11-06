import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/lyrics_translation_modal.dart';
import 'package:material_ui/material_ui.dart';

import 'translation_modal_harness.dart';

void main() {
  TranslationReady readyState() => TranslationReady(
    fakeTranslationInfo(),
    testTranslatePlugin,
    'ja',
    const ['The last kiss', 'Tasted like cigarettes'],
    false,
  );

  TranslationPrefs onPrefs([
    LyricsTranslationDisplay display = LyricsTranslationDisplay.underLine,
  ]) => TranslationPrefs(
    show: true,
    display: display,
    service: testTranslatePlugin,
    noticeAcknowledged: {testTranslatePlugin},
  );

  double? fontSizeOf(WidgetTester tester, Finder textFinder) =>
      DefaultTextStyle.of(tester.element(textFinder)).style.fontSize;

  testWidgets(
    'underLine shows original above smaller translation and credit line',
    (tester) async {
      await pumpTranslationModal(
        tester,
        state: readyState(),
        settings: onPrefs(LyricsTranslationDisplay.underLine),
      );

      final orig = find.text('最後のキスは');
      final trans = find.text('The last kiss');
      expect(orig, findsOneWidget);
      expect(trans, findsOneWidget);
      expect(find.text('Translated by Test Translate'), findsOneWidget);
      expect(find.text('Japanese · detected'), findsOneWidget);

      expect(fontSizeOf(tester, orig), 20);
      expect(fontSizeOf(tester, trans), closeTo(20 * 0.62, 0.01));
      expect(tester.getTopLeft(orig).dy, lessThan(tester.getTopLeft(trans).dy));
    },
  );

  testWidgets('replace shows translation as main line below smaller original', (
    tester,
  ) async {
    await pumpTranslationModal(
      tester,
      state: readyState(),
      settings: onPrefs(LyricsTranslationDisplay.replace),
    );

    final orig = find.text('最後のキスは');
    final trans = find.text('The last kiss');
    expect(fontSizeOf(tester, trans), 20);
    expect(fontSizeOf(tester, orig), closeTo(20 * 0.5, 0.01));
    expect(tester.getTopLeft(orig).dy, lessThan(tester.getTopLeft(trans).dy));
  });

  testWidgets(
    'segmented button reflects and writes display setting while keeping modal open',
    (tester) async {
      final h = await pumpTranslationModal(
        tester,
        state: readyState(),
        settings: onPrefs(),
      );

      SegmentedButton<LyricsTranslationDisplay> segmented() =>
          tester.widget(find.byType(SegmentedButton<LyricsTranslationDisplay>));

      expect(segmented().selected, {LyricsTranslationDisplay.underLine});

      await tester.tap(find.text('Replace line'));
      await settleModal(tester);
      expect(h.prefs.display, LyricsTranslationDisplay.replace);
      expect(segmented().selected, {LyricsTranslationDisplay.replace});
      expect(find.byType(LyricsTranslationModal), findsOneWidget);

      await tester.tap(find.text('Under line'));
      await settleModal(tester);
      expect(h.prefs.display, LyricsTranslationDisplay.underLine);
      expect(segmented().selected, {LyricsTranslationDisplay.underLine});
    },
  );

  testWidgets(
    'when translation is off, hides segmented button, translation line, and credit',
    (tester) async {
      await pumpTranslationModal(
        tester,
        state: TranslationOff(fakeTranslationInfo()),
        settings: TranslationPrefs(
          show: false,
          service: testTranslatePlugin,
          noticeAcknowledged: {testTranslatePlugin},
        ),
      );

      expect(
        find.byType(SegmentedButton<LyricsTranslationDisplay>),
        findsNothing,
      );
      expect(find.text('最後のキスは'), findsOneWidget);
      expect(find.text('The last kiss'), findsNothing);
      expect(find.text('Translated by Test Translate'), findsNothing);
    },
  );

  testWidgets('synced lyrics follow playback position', (tester) async {
    final h = await pumpTranslationModal(
      tester,
      state: readyState(),
      settings: onPrefs(),
    );
    expect(find.text('最後のキスは'), findsOneWidget);
    expect(find.text('The last kiss'), findsOneWidget);

    h.audio.emitPosition.add(const Duration(seconds: 6));
    await tester.pump();
    expect(find.text('タバコのflavorがした'), findsOneWidget);
    expect(find.text('Tasted like cigarettes'), findsOneWidget);
  });

  testWidgets('plain lyrics show the first non-empty line', (tester) async {
    final h = await pumpTranslationModal(
      tester,
      state: readyState(),
      settings: onPrefs(),
      lyrics: const Lyrics(
        lines: [
          LyricLine(Duration.zero, '   '),
          LyricLine(Duration.zero, 'Plain first line'),
        ],
        synced: false,
        source: LyricsSource.sidecar,
      ),
    );
    h.audio.emitPosition.add(const Duration(seconds: 10));
    await tester.pump();
    expect(find.text('Plain first line'), findsOneWidget);
  });

  testWidgets('an empty line shows the nearest previous non-empty line', (
    tester,
  ) async {
    final h = await pumpTranslationModal(
      tester,
      lyrics: const Lyrics(
        lines: [
          LyricLine(Duration.zero, 'Line one'),
          LyricLine(Duration(seconds: 5), 'Line two'),
          LyricLine(Duration(seconds: 10), ''),
          LyricLine(Duration(seconds: 20), 'Line four'),
        ],
        synced: true,
        source: LyricsSource.sidecar,
      ),
    );
    h.audio.emitPosition.add(const Duration(seconds: 12));
    await tester.pump();
    expect(find.text('Line two'), findsOneWidget);
    expect(find.text('Line one'), findsNothing);
  });

  testWidgets('an empty first line shows the next non-empty line', (
    tester,
  ) async {
    final h = await pumpTranslationModal(
      tester,
      lyrics: const Lyrics(
        lines: [
          LyricLine(Duration.zero, ''),
          LyricLine(Duration(seconds: 3), 'First sung line'),
        ],
        synced: true,
        source: LyricsSource.sidecar,
      ),
    );
    h.audio.emitPosition.add(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('First sung line'), findsOneWidget);
  });
}
