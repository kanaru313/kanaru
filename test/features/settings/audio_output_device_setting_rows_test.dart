import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/audio_output_device.dart';
import 'package:kanaru/core/player/audio_output_devices_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/audio_output_device_setting_rows.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

AudioOutputDevice device(String name, String description) =>
    AudioOutputDevice(name: name, description: description);

final devices = [
  device('auto', 'Autoselect device'),
  device('pipewire', 'Default (pipewire)'),
  device('pipewire/spk', 'PW Speaker'),
  device('pipewire/hdmi', 'PW HDMI'),
  device('pulse/spk', 'Pulse Speaker'),
  device('alsa', 'Default (alsa)'),
  device('alsa/hw:0', 'ALSA Card'),
];

late FakeAudioBackend backend;
late ProviderContainer container;

PlaybackPrefs get playback => container.read(settingsProvider).playback;

Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

Future<void> pumpRow(
  WidgetTester tester, {
  PlaybackPrefs prefs = const PlaybackPrefs(),
  List<AudioOutputDevice>? listed,
  Size size = const Size(1000, 1400),
  double textScale = 1,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  backend = FakeAudioBackend()..devices = listed ?? devices;
  container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(backend),
      initialSettingsProvider.overrideWithValue(AppSettings(playback: prefs)),
    ],
  );
  addTearDown(container.dispose);
  // The player applies the settings and reports a device that fails.
  container.listen(playerServiceProvider, (_, _) {});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        // Scrollable like the settings page: a long subtitle wraps and grows.
        home: const Scaffold(
          body: SingleChildScrollView(child: AudioOutputDeviceSettingRow()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openDialog(WidgetTester tester) async {
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

PlaybackPrefs saved(String name, String description) =>
    const PlaybackPrefs().withAudioDevice(name: name, description: description);

void main() {
  testWidgets('says Automatic when no device is saved', (tester) async {
    await pumpRow(tester);

    expect(find.text('Automatic (system default)'), findsOneWidget);
  });

  testWidgets('lists Automatic and the main driver, others folded', (
    tester,
  ) async {
    await pumpRow(tester);
    await openDialog(tester);

    expect(inDialog(find.text('Automatic (system default)')), findsOneWidget);
    expect(inDialog(find.text('PW Speaker')), findsOneWidget);
    expect(inDialog(find.text('PW HDMI')), findsOneWidget);
    // A bare driver name is the driver default, not a device.
    expect(inDialog(find.text('Default (pipewire)')), findsNothing);
    expect(inDialog(find.text('Pulse Speaker')), findsNothing);

    await tester.tap(find.text('Other outputs'));
    await tester.pumpAndSettle();

    expect(inDialog(find.text('Pulse Speaker')), findsOneWidget);
    expect(inDialog(find.text('ALSA Card')), findsOneWidget);
    expect(inDialog(find.text('PulseAudio')), findsOneWidget);
    expect(inDialog(find.text('ALSA')), findsOneWidget);
    expect(inDialog(find.text('Default (alsa)')), findsNothing);
  });

  testWidgets('choosing a device stores its name and description', (
    tester,
  ) async {
    await pumpRow(tester);
    await openDialog(tester);

    await tester.tap(inDialog(find.text('PW HDMI')));
    await tester.pumpAndSettle();

    expect(playback.audioDeviceName, 'pipewire/hdmi');
    expect(playback.audioDeviceDescription, 'PW HDMI');
    expect(find.byType(AlertDialog), findsNothing);
    expect(backend.audioCalls, ['setAudioDevice(pipewire/hdmi)']);
    expect(find.text('PW HDMI'), findsOneWidget);
  });

  testWidgets('a device of another driver can be chosen', (tester) async {
    await pumpRow(tester);
    await openDialog(tester);
    await tester.tap(find.text('Other outputs'));
    await tester.pumpAndSettle();

    await tester.tap(inDialog(find.text('ALSA Card')));
    await tester.pumpAndSettle();

    expect(playback.audioDeviceName, 'alsa/hw:0');
  });

  testWidgets('Automatic clears both fields', (tester) async {
    await pumpRow(tester, prefs: saved('pipewire/spk', 'PW Speaker'));
    await openDialog(tester);

    await tester.tap(inDialog(find.text('Automatic (system default)')));
    await tester.pumpAndSettle();

    expect(playback.audioDeviceName, isNull);
    expect(playback.audioDeviceDescription, isNull);
  });

  testWidgets('a saved device that is gone is named as missing', (
    tester,
  ) async {
    await pumpRow(tester, prefs: saved('pipewire/gone', 'Old Headset'));

    expect(
      find.text('Old Headset — not available, using Automatic'),
      findsOneWidget,
    );

    await openDialog(tester);
    final missing = inDialog(
      find.text('Old Headset — not available, using Automatic'),
    );
    expect(missing, findsOneWidget);
    expect(
      tester
          .widget<RadioListTile<String>>(
            find.ancestor(
              of: missing,
              matching: find.byType(RadioListTile<String>),
            ),
          )
          .enabled,
      isFalse,
    );
    expect(backend.audioCalls, isEmpty);
  });

  testWidgets('a device that failed to open says so', (tester) async {
    await pumpRow(tester, prefs: saved('pipewire/spk', 'PW Speaker'));
    backend.emitAudioDeviceFailed('pipewire/spk');
    await tester.pumpAndSettle();

    expect(
      find.text('PW Speaker — could not be opened, using Automatic'),
      findsOneWidget,
    );
  });

  testWidgets('choosing the failed device again retries it', (tester) async {
    await pumpRow(tester, prefs: saved('pipewire/spk', 'PW Speaker'));
    expect(backend.audioCalls, ['setAudioDevice(pipewire/spk)']);
    backend.emitAudioDeviceFailed('pipewire/spk');
    await tester.pumpAndSettle();

    await openDialog(tester);
    await tester.tap(inDialog(find.text('PW Speaker')));
    await tester.pumpAndSettle();

    expect(playback.audioDeviceName, 'pipewire/spk');
    expect(container.read(audioOutputFailedDeviceProvider), isNull);
    expect(backend.audioCalls, [
      'setAudioDevice(pipewire/spk)',
      'setAudioDevice(pipewire/spk)',
    ]);
    expect(find.text('PW Speaker'), findsOneWidget);
  });

  testWidgets('the dialog follows the list while it is open', (tester) async {
    await pumpRow(tester);
    await openDialog(tester);
    expect(inDialog(find.text('PW Dock')), findsNothing);

    backend.emitAudioDevices([...devices, device('pipewire/dock', 'PW Dock')]);
    await tester.pumpAndSettle();

    expect(inDialog(find.text('PW Dock')), findsOneWidget);
  });

  testWidgets('with no devices only Automatic and a note are shown', (
    tester,
  ) async {
    await pumpRow(tester, listed: const []);
    await openDialog(tester);

    expect(inDialog(find.text('Automatic (system default)')), findsOneWidget);
    expect(
      inDialog(find.text('No other output devices found')),
      findsOneWidget,
    );
  });

  testWidgets('tapping the selected device closes the dialog as it is', (
    tester,
  ) async {
    await pumpRow(tester, prefs: saved('pipewire/spk', 'PW Speaker'));
    backend.audioCalls.clear();
    await openDialog(tester);

    await tester.tap(inDialog(find.text('PW Speaker')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(playback.audioDeviceName, 'pipewire/spk');
    expect(backend.audioCalls, isEmpty);
  });

  testWidgets('tapping Automatic while it is selected closes the dialog', (
    tester,
  ) async {
    await pumpRow(tester);
    await openDialog(tester);

    await tester.tap(inDialog(find.text('Automatic (system default)')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(playback.audioDeviceName, isNull);
  });

  group('a 200 character description at 360 px, text scale 2, Vietnamese', () {
    final long = 'Loa ${'rất dài ' * 25}'.trim().substring(0, 200);
    final listed = [
      device('auto', 'Autoselect device'),
      device('pipewire/long', long),
      device('pipewire/other', 'Other'),
    ];

    Future<void> pumpNarrow(WidgetTester tester, PlaybackPrefs prefs) =>
        pumpRow(
          tester,
          prefs: prefs,
          listed: listed,
          size: const Size(360, 800),
          textScale: 2,
          locale: const Locale('vi'),
        );

    testWidgets('the row says a missing device', (tester) async {
      await pumpNarrow(tester, saved('pipewire/gone', long));

      expect(find.textContaining('Loa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the row says a failed device', (tester) async {
      await pumpNarrow(tester, saved('pipewire/long', long));
      backend.emitAudioDeviceFailed('pipewire/long');
      await tester.pumpAndSettle();

      expect(find.textContaining('Loa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the dialog lists it, and the missing note', (tester) async {
      await pumpNarrow(tester, saved('pipewire/gone', long));
      await tester.ensureVisible(
        find.byType(FilledButton),
      ); // below the long text
      await openDialog(tester);

      expect(inDialog(find.text(long)), findsOneWidget);
      expect(inDialog(find.textContaining('Loa')), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
