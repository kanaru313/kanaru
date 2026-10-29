import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/lyrics_setting_rows.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:material_ui/material_ui.dart';

import 'online_lyrics_switch_harness.dart';

void main() {
  Finder switchOf(String title) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(SettingRow)),
    matching: find.byType(Switch),
  );
  final auto = switchOf('Find lyrics online automatically (LRCLIB)');
  final lrc = switchOf('Save picked lyrics as .lrc files');
  final notice = find.text('Find lyrics online automatically?');

  Future<LyricsRowsHarness> pump(
    WidgetTester tester, {
    bool autoFetch = false,
    bool autoConsent = false,
    bool manualConsent = false,
  }) => LyricsRowsHarness.create(
    tester,
    const LyricsSettingRows(),
    autoFetch: autoFetch,
    autoConsent: autoConsent,
    manualConsent: manualConsent,
  );

  OnlineLyricsPrefs prefsOf(LyricsRowsHarness r) =>
      r.container.read(settingsProvider).onlineLyrics;

  testWidgets(
    'the first turn on asks; Cancel keeps it off and writes nothing',
    (tester) async {
      final r = await pump(tester);
      expect(tester.widget<Switch>(auto).value, isFalse);

      await tester.tap(auto);
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(notice, findsNothing);
      expect(tester.widget<Switch>(auto).value, isFalse);
      expect(prefsOf(r).autoFetch, isFalse);
      expect(prefsOf(r).noticeAcknowledged, isEmpty);
    },
  );

  testWidgets('Turn on records the consent; later toggles never ask', (
    tester,
  ) async {
    final r = await pump(tester);
    await tester.tap(auto);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(auto).value, isTrue);
    expect(prefsOf(r).autoFetch, isTrue);
    expect(
      prefsOf(r).noticeAcknowledged,
      contains(r.registration.autoConsentKey),
    );

    await tester.tap(auto);
    await tester.pumpAndSettle();
    expect(notice, findsNothing);
    expect(tester.widget<Switch>(auto).value, isFalse);
    expect(
      prefsOf(r).noticeAcknowledged,
      contains(r.registration.autoConsentKey),
    );

    await tester.tap(auto);
    await tester.pumpAndSettle();
    expect(notice, findsNothing);
    expect(tester.widget<Switch>(auto).value, isTrue);
  });

  testWidgets('consent to search alone does not skip the automatic notice', (
    tester,
  ) async {
    final r = await pump(tester, manualConsent: true);
    await tester.tap(auto);
    await tester.pumpAndSettle();

    expect(notice, findsOneWidget);
    expect(prefsOf(r).autoFetch, isFalse);
  });

  testWidgets('a switch kept on without this provider\'s key shows off', (
    tester,
  ) async {
    await pump(tester, autoFetch: true);
    expect(tester.widget<Switch>(auto).value, isFalse);
  });

  testWidgets('the .lrc switch is never disabled and writes writeLrc', (
    tester,
  ) async {
    final r = await pump(tester);
    expect(tester.widget<Switch>(lrc).onChanged, isNotNull);
    expect(tester.widget<Switch>(lrc).value, isFalse);

    await tester.tap(lrc);
    await tester.pump();
    expect(prefsOf(r).writeLrc, isTrue);
    expect(tester.widget<Switch>(lrc).value, isTrue);
    // No consent needed, none given.
    expect(prefsOf(r).noticeAcknowledged, isEmpty);

    await tester.tap(lrc);
    await tester.pump();
    expect(prefsOf(r).writeLrc, isFalse);
  });
}
