import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/audio_replay_gain_setting_rows.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

late ProviderContainer container;

PlaybackPrefs get playback => container.read(settingsProvider).playback;

Future<void> pumpRows(WidgetTester tester, PlaybackPrefs prefs) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(AppSettings(playback: prefs)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: ReplayGainSettingRows()),
        ),
      ),
    ),
  );
  // The full or compact choice settles on the next frame.
  await tester.pump();
}

/// Picks a mode from the segmented button, or from the dropdown a narrow
/// row shows instead.
Future<void> pickMode(WidgetTester tester, String label) async {
  final dropdown = find.byType(DropdownMenu<ReplayGainMode>);
  if (dropdown.evaluate().isNotEmpty) {
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
  } else {
    await tester.tap(find.text(label));
  }
  await tester.pumpAndSettle();
}

Finder get preampDropdown =>
    find.byWidgetPredicate((w) => w is DropdownMenu<double>);

Switch get clipSwitch => tester0.widget<Switch>(find.byType(Switch));
late WidgetTester tester0;

void main() {
  testWidgets('with the mode off the preamp and clipping are disabled', (
    tester,
  ) async {
    tester0 = tester;
    await pumpRows(tester, const PlaybackPrefs(replayGainPreampDb: 3));

    expect(
      tester.widget<DropdownMenu<double>>(preampDropdown).enabled,
      isFalse,
    );
    expect(clipSwitch.onChanged, isNull);
    // Still shows what will apply.
    expect(clipSwitch.value, isTrue);
    expect(
      tester.widget<DropdownMenu<double>>(preampDropdown).initialSelection,
      3.0,
    );
    expect(find.text('+3 dB'), findsWidgets);
  });

  testWidgets('picking Album stores the mode and enables the others', (
    tester,
  ) async {
    tester0 = tester;
    await pumpRows(tester, const PlaybackPrefs());

    await pickMode(tester, 'Album');

    expect(playback.replayGainMode, ReplayGainMode.album);
    expect(tester.widget<DropdownMenu<double>>(preampDropdown).enabled, isTrue);
    expect(clipSwitch.onChanged, isNotNull);
  });

  testWidgets('every mode can be picked', (tester) async {
    tester0 = tester;
    await pumpRows(tester, const PlaybackPrefs());

    for (final (label, mode) in [
      ('Track', ReplayGainMode.track),
      ('Automatic', ReplayGainMode.auto),
      ('Off', ReplayGainMode.off),
    ]) {
      await pickMode(tester, label);
      expect(playback.replayGainMode, mode, reason: label);
    }
  });

  testWidgets('picking a preamp stores it', (tester) async {
    tester0 = tester;
    await pumpRows(
      tester,
      const PlaybackPrefs(replayGainMode: ReplayGainMode.track),
    );

    await tester.tap(find.byType(DropdownMenu<double>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+3 dB').last);
    await tester.pumpAndSettle();

    expect(playback.replayGainPreampDb, 3.0);
  });

  testWidgets('a preamp typed into the file still shows', (tester) async {
    tester0 = tester;
    await pumpRows(
      tester,
      const PlaybackPrefs(
        replayGainMode: ReplayGainMode.track,
        replayGainPreampDb: -2.5,
      ),
    );

    expect(find.text('−2.5 dB'), findsWidgets);
  });

  testWidgets('the clipping switch stores its value', (tester) async {
    tester0 = tester;
    await pumpRows(
      tester,
      const PlaybackPrefs(replayGainMode: ReplayGainMode.track),
    );

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(playback.replayGainPreventClipping, isFalse);
  });

  test('formatDb', () {
    expect(formatDb(0), '0');
    expect(formatDb(3), '+3');
    expect(formatDb(-3), '−3');
    expect(formatDb(2.5), '+2.5');
  });
}
