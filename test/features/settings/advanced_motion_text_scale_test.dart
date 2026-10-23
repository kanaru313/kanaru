import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

late ProviderContainer container;

/// Opens the whole app with [settings] in a [size] window.
Future<void> _pumpApp(
  WidgetTester tester,
  AppSettings settings, {
  Size size = const Size(1280, 900),
  bool systemReducedMotion = false,
  double systemTextScale = 1,
  bool withTrack = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = const [Locale('en')];
  tester.platformDispatcher.textScaleFactorTestValue = systemTextScale;
  // The seek bar's wave never settles while music plays, so tests with a
  // track turn motion off from the system side as the other player tests do.
  if (systemReducedMotion || withTrack) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  }
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  container = ProviderContainer(
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      initialSettingsProvider.overrideWithValue(settings),
    ],
  );
  addTearDown(container.dispose);
  if (withTrack) {
    await container.read(playerServiceProvider.notifier).openTracks([
      const Track(
        uri: '/music/a.flac',
        title: 'A rather long song title for a large text size',
        artist: 'An artist with a long name',
      ),
    ]);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KanaruApp()),
  );
  await tester.pumpAndSettle();
}

/// The media query a page of the app sees.
MediaQueryData _pageMedia(WidgetTester tester) =>
    MediaQuery.of(tester.element(find.byType(Scaffold).first));

void main() {
  group('appTextScaler', () {
    double scaled(double system, double fontScale) =>
        appTextScaler(TextScaler.linear(system), fontScale).scale(10);

    test('1.0 leaves the system scale alone', () {
      final system = TextScaler.linear(1.3);
      expect(identical(appTextScaler(system, 1), system), isTrue);
    });

    test('multiplies the system scale', () {
      expect(scaled(1, 1.5), closeTo(15, 1e-9));
      expect(scaled(1, 0.8), closeTo(8, 1e-9));
      expect(scaled(1.2, 1.25), closeTo(15, 1e-9));
      expect(scaled(1.5, 0.8), closeTo(12, 1e-9));
    });

    test('enlarging stops at twice the normal size', () {
      expect(scaled(1.5, 1.5), closeTo(20, 1e-9));
    });

    test('never undoes a system scale above the cap', () {
      expect(scaled(2.5, 1.5), closeTo(25, 1e-9));
      expect(scaled(2.5, 0.8), closeTo(20, 1e-9));
    });
  });

  testWidgets('animations off forces reduced motion on pages and dialogs', (
    tester,
  ) async {
    await _pumpApp(tester, const AppSettings(animations: false));
    expect(_pageMedia(tester).disableAnimations, isTrue);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    showDialog<void>(
      context: navigator.context,
      builder: (_) => const AlertDialog(content: Text('probe')),
    );
    await tester.pumpAndSettle();
    expect(
      MediaQuery.disableAnimationsOf(tester.element(find.text('probe'))),
      isTrue,
    );
  });

  testWidgets('animations on follows the system', (tester) async {
    await _pumpApp(tester, const AppSettings());
    expect(_pageMedia(tester).disableAnimations, isFalse);
  });

  testWidgets('animations on keeps the system reduced motion', (tester) async {
    await _pumpApp(tester, const AppSettings(), systemReducedMotion: true);
    expect(_pageMedia(tester).disableAnimations, isTrue);
  });

  testWidgets('switching animations off applies at once', (tester) async {
    await _pumpApp(tester, const AppSettings());
    container.read(settingsProvider.notifier).setAnimations(false);
    await tester.pump();
    expect(_pageMedia(tester).disableAnimations, isTrue);
  });

  testWidgets('the font size scales the text of every page', (tester) async {
    await _pumpApp(
      tester,
      const AppSettings(display: DisplayPrefs(fontScale: 1.5)),
    );
    expect(_pageMedia(tester).textScaler.scale(10), closeTo(15, 1e-9));

    container
        .read(settingsProvider.notifier)
        .setDisplay(const DisplayPrefs(fontScale: 0.8));
    await tester.pump();
    expect(_pageMedia(tester).textScaler.scale(10), closeTo(8, 1e-9));
  });

  testWidgets('the font size multiplies the system text scale', (tester) async {
    await _pumpApp(
      tester,
      const AppSettings(display: DisplayPrefs(fontScale: 1.5)),
      systemTextScale: 1.5,
    );
    expect(_pageMedia(tester).textScaler.scale(10), closeTo(20, 1e-9));
  });

  // Overflow during layout fails the test on its own; these walk the main
  // screens at the largest font size.
  for (final size in const [Size(1280, 900), Size(480, 900)]) {
    testWidgets(
      'the largest font size fits a ${size.width.toInt()} px window',
      (tester) async {
        await _pumpApp(
          tester,
          const AppSettings(display: DisplayPrefs(fontScale: 1.5)),
          size: size,
          withTrack: true,
        );

        // Settings, from the top bar.
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('Text size'), findsWidgets);

        // Now Playing over the shell.
        container.read(nowPlayingOpenProvider.notifier).open();
        await tester.pumpAndSettle();
        expect(
          find.text('A rather long song title for a large text size'),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
