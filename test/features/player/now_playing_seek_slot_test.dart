import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_seek_slot.dart';
import 'package:kanaru/features/player/seek_bar.dart';
import 'package:kanaru/features/player/waveform/waveform_seek_track.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import 'waveform/waveform_seek_track_harness.dart';

void main() {
  final h = WaveSlotHarness();

  Future<void> mountSlot(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(
            child: SizedBox(width: 400, child: NowPlayingSeekSlot()),
          ),
        ),
      ),
    ),
  );

  void setWaveform({required bool on}) => h.container
      .read(settingsProvider.notifier)
      .setDisplay(DisplayPrefs(waveformSeekBar: on));

  double slotHeight() => h.container.read(nowPlayingSeekSlotHeightProvider);

  testWidgets('on by default: the waveform track in a 48 px slot', (
    tester,
  ) async {
    await h.start(tester);
    await mountSlot(tester);
    await h.settle();

    expect(find.byType(WaveformSeekTrack), findsOneWidget);
    expect(find.byType(SeekTrack), findsNothing);
    expect(slotHeight(), 48);
  });

  testWidgets('off: the flat track, 24 px, and nothing is read', (
    tester,
  ) async {
    await h.start(tester);
    setWaveform(on: false);
    expect(h.container.read(settingsProvider).display.waveformSeekBar, isFalse);
    await mountSlot(tester);
    await h.settle();

    expect(find.byType(WaveformSeekTrack), findsNothing);
    expect(find.byType(SeekTrack), findsOneWidget);
    expect(tester.getSize(find.byType(SeekTrack)).height, seekHitHeight);
    expect(slotHeight(), seekHitHeight);
    expect(h.reader.begun, isEmpty);
    expect(h.reader.reads, isEmpty);
  });

  testWidgets('turning it off while a waveform loads cancels the read', (
    tester,
  ) async {
    await h.start(tester);
    await mountSlot(tester);
    await h.settle();
    expect(h.reader.isReading(trackA.uri), isTrue);

    setWaveform(on: false);
    await h.settle();

    expect(find.byType(WaveformSeekTrack), findsNothing);
    expect(find.byType(SeekTrack), findsOneWidget);
    expect(h.reader.cancels, isNotEmpty);
    expect(h.reader.isReading(trackA.uri), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning it back on brings the waveform and 48 px back', (
    tester,
  ) async {
    await h.start(tester);
    setWaveform(on: false);
    await mountSlot(tester);
    await h.settle();

    setWaveform(on: true);
    await h.settle();

    expect(find.byType(WaveformSeekTrack), findsOneWidget);
    expect(slotHeight(), 48);
    expect(h.reader.isReading(trackA.uri), isTrue);
  });
}
