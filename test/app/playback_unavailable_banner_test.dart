import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/shell/playback_unavailable_banner.dart';
import 'package:kanaru/core/player/audio_backend.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/unavailable_audio_backend.dart';
import 'package:material_ui/material_ui.dart';

import '../core/player/fake_audio_backend.dart';

Future<void> pumpWith(
  WidgetTester tester,
  AudioBackend backend, {
  Size size = const Size(1280, 800),
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
      child: KanaruApp(locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows when the audio engine is unavailable', (tester) async {
    await pumpWith(tester, UnavailableAudioBackend());

    expect(find.text('Audio engine not found'), findsOneWidget);
    expect(find.byType(PlaybackUnavailableBanner), findsOneWidget);
  });

  testWidgets('shows on narrow windows too', (tester) async {
    await pumpWith(
      tester,
      UnavailableAudioBackend(),
      size: const Size(480, 800),
    );

    expect(find.text('Audio engine not found'), findsOneWidget);
  });

  testWidgets('is in Vietnamese with the Vietnamese locale', (tester) async {
    await pumpWith(
      tester,
      UnavailableAudioBackend(),
      locale: const Locale('vi'),
    );

    expect(find.text('Không tìm thấy bộ máy phát nhạc'), findsOneWidget);
  });

  testWidgets('is absent with a working audio engine', (tester) async {
    await pumpWith(tester, FakeAudioBackend());

    expect(find.text('Audio engine not found'), findsNothing);
  });
}
