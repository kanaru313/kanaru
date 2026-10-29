import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/embedded_lyrics_reader.dart';
import 'package:kanaru/core/lyrics/lrc_sidecar_reader.dart';
import 'package:kanaru/core/lyrics/online/lrc_sidecar_writer.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_streams.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';

import '../../player/fake_audio_backend.dart';
import '../fake_lyrics_readers.dart';
import 'counting_http_client.dart';
import 'fake_lyrics_provider.dart';
import 'lookup_test_harness.dart';

/// Records `.lrc` writes and answers [result].
class FakeLrcSidecarWriter implements LrcSidecarWriter {
  LrcWriteResult result = LrcWriteResult.written;
  final writes = <(String, LyricsBody)>[];

  /// The `replace` flag of each write, in order.
  final replaces = <bool>[];

  /// Answers instead of [result] when set (a real writer, say).
  LrcSidecarWriter? delegate;

  /// Runs when a write is asked for, before it answers.
  Future<void> Function()? onWrite;

  @override
  Future<LrcWriteResult> write(
    String audioPath,
    LyricsBody body, {
    bool replace = false,
  }) async {
    writes.add((audioPath, body));
    replaces.add(replace);
    await onWrite?.call();
    return delegate?.write(audioPath, body, replace: replace) ?? result;
  }
}

/// A song the fake provider's candidates match when its fields are the
/// defaults.
Track fakeSong(
  String path, {
  String? title = 'Song',
  String? artist = 'Artist',
}) => Track(
  uri: path,
  title: title ?? path.split('/').last.split('.').first,
  artist: artist,
  album: 'Alb',
  duration: const Duration(seconds: 200),
);

/// Debounce the rigs use, short enough for real timers.
const rigDebounce = Duration(milliseconds: 30);

/// A player, a library, a fake provider and the status provider, watched
/// like Now Playing watches it.
class StatusRig {
  StatusRig._();

  late final LyricsHarness h;
  late final FakeLyricsProvider fake;
  late final CountingHttpClient client;
  final embedded = FakeEmbeddedLyricsReader();
  final sidecar = FakeLrcSidecarReader();
  final writer = FakeLrcSidecarWriter();
  final statuses = <PlayingLyricsStatus?>[];
  ProviderSubscription<PlayingLyricsStatus?>? _sub;

  ProviderContainer get container => h.container;
  PlayerService get player => container.read(playerServiceProvider.notifier);
  PlayingLyricsStatus? get status =>
      container.read(playingLyricsStatusProvider);

  /// Requests the fake provider has been asked to make.
  int get requests => fake.lookupCalls + fake.searchCalls;

  /// Starts watching the status (Now Playing shown).
  void watch() {
    _sub ??= container.listen(
      playingLyricsStatusProvider,
      (_, next) => statuses.add(next),
      fireImmediately: true,
    );
  }

  /// Stops watching (Now Playing hidden).
  void unwatch() {
    _sub?.close();
    _sub = null;
  }

  /// Closes Now Playing and shows it again once the providers have been
  /// disposed, so everything is read anew.
  Future<void> rewatch({void Function()? whileClosed}) async {
    unwatch();
    await pumpEventQueue();
    whileClosed?.call();
    watch();
  }

  Future<void> play(List<Track> tracks) => player.openTracks(tracks);

  /// Waits until [done] holds, polling real time; fails after two seconds.
  Future<void> until(bool Function() done) async {
    final end = DateTime.now().add(const Duration(seconds: 2));
    while (!done()) {
      if (DateTime.now().isAfter(end)) fail('condition not reached: $status');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// Lets timers shorter than [rigDebounce] times four and streams run.
  Future<void> settle() => Future<void>.delayed(rigDebounce * 4);
}

Future<StatusRig> createStatusRig({
  bool autoFetch = true,
  bool autoConsent = true,
  bool manualConsent = true,
  bool withDatabase = true,
  Duration debounce = rigDebounce,
  List<Override> overrides = const [],
}) async {
  final rig = StatusRig._()
    ..fake = FakeLyricsProvider()
    ..client = CountingHttpClient();
  rig.h = await createHarness(
    [LyricsProviderRegistration(rig.fake)],
    client: rig.client,
    autoFetch: autoFetch,
    autoConsent: autoConsent,
    manualConsent: manualConsent,
    withDatabase: withDatabase,
    overrides: [
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      embeddedLyricsReaderProvider.overrideWithValue(rig.embedded),
      lrcSidecarReaderProvider.overrideWithValue(rig.sidecar),
      lrcSidecarWriterProvider.overrideWithValue(rig.writer),
      onlineLyricsDebounceProvider.overrideWithValue(debounce),
      ...overrides,
    ],
  );
  rig.container.listen(playerServiceProvider, (_, _) {});
  addTearDown(rig.unwatch);
  return rig;
}
