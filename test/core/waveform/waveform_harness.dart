import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/waveform/waveform.dart';
import 'package:kanaru/core/waveform/waveform_controller.dart';

import '../player/fake_audio_backend.dart';
import 'fake_waveform_reader.dart';

/// A [ProviderContainer] with a real player on a fake engine and a
/// [FakeWaveformReader], created per test and disposed after it.
class WaveformHarness {
  WaveformHarness() {
    reader = FakeWaveformReader();
    container = create(reader);
    addTearDown(() => container.dispose());
  }

  late final FakeWaveformReader reader;
  late ProviderContainer container;

  /// A container that reads waveforms with [waveformReader].
  ProviderContainer create(WaveformReader waveformReader) {
    final created = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        waveformReaderProvider.overrideWithValue(waveformReader),
      ],
    );
    created.listen(playerServiceProvider, (_, _) {});
    return created;
  }

  PlayerService service() => container.read(playerServiceProvider.notifier);
  WaveformController waveforms() =>
      container.read(waveformControllerProvider.notifier);
  PlayingWaveform? shown() => container.read(waveformControllerProvider);
  Future<void> settle() => pumpEventQueue();

  Future<void> open(List<String> uris) =>
      service().openTracks([for (final u in uris) Track(uri: u, title: u)]);
}
