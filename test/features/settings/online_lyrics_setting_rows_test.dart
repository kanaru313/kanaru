import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/lyrics_setting_rows.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';
import '../../core/lyrics/online/lookup_test_harness.dart';
import 'online_lyrics_switch_harness.dart';

void main() {
  Finder switchOf(String title) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(SettingRow)),
    matching: find.byType(Switch),
  );
  final auto = switchOf('Find lyrics online automatically');
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

  testWidgets('there is no switch for writing .lrc files', (tester) async {
    await pump(tester);
    expect(find.text('Save picked lyrics as .lrc files'), findsNothing);
  });

  group('consent withdrawal', () {
    final withdraw = find.widgetWithText(FilledButton, 'Withdraw');

    Future<void> confirmWithdraw(WidgetTester tester) async {
      await tester.tap(withdraw);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Withdraw'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('nothing allowed reads as not allowed and Withdraw is off', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Not allowed'), findsOneWidget);
      expect(tester.widget<FilledButton>(withdraw).onPressed, isNull);
    });

    testWidgets('manual only reads as manual', (tester) async {
      await pump(tester, manualConsent: true);
      expect(find.text('Manual search allowed'), findsOneWidget);
      expect(tester.widget<FilledButton>(withdraw).onPressed, isNotNull);
    });

    testWidgets('Cancel keeps everything', (tester) async {
      final r = await pump(
        tester,
        autoFetch: true,
        autoConsent: true,
        manualConsent: true,
      );
      await tester.tap(withdraw);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(prefsOf(r).autoFetch, isTrue);
      expect(prefsOf(r).noticeAcknowledged, hasLength(2));
    });

    testWidgets('removes both keys, turns auto off and the notice returns', (
      tester,
    ) async {
      final r = await pump(
        tester,
        autoFetch: true,
        autoConsent: true,
        manualConsent: true,
      );
      expect(find.text('Manual and automatic search allowed'), findsOneWidget);

      await confirmWithdraw(tester);

      expect(prefsOf(r).autoFetch, isFalse);
      expect(prefsOf(r).noticeAcknowledged, isEmpty);
      expect(find.text('Not allowed'), findsOneWidget);
      expect(tester.widget<FilledButton>(withdraw).onPressed, isNull);
      expect(tester.widget<Switch>(auto).value, isFalse);

      await tester.tap(auto);
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
    });

    testWidgets('no request leaves after it', (tester) async {
      final r = await pump(
        tester,
        autoFetch: true,
        autoConsent: true,
        manualConsent: true,
      );
      final fake = r.registration.provider as FakeLyricsProvider;

      await confirmWithdraw(tester);
      await tester.runAsync(() => r.h.lookups.start(fakeTarget, auto: false));
      await tester.runAsync(() => r.h.lookups.start(fakeTarget, auto: true));

      expect(fake.lookupCalls, 0);
      expect(fake.searchCalls, 0);
    });
  });
}
