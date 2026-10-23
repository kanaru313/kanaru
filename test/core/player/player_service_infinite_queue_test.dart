import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_audio_backend.dart';

final _songs = [
  for (final name in ['a', 'b', 'c']) Track.fromPath('/music/$name.mp3'),
];

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService service() => container.read(playerServiceProvider.notifier);
  int index() => container.read(playerServiceProvider).queue.index;

  void launch({required bool endless}) {
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        initialSettingsProvider.overrideWithValue(
          AppSettings(playback: PlaybackPrefs(infiniteQueue: endless)),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(playerServiceProvider, (_, _) {});
  }

  test('next on the last track goes to the first when endless', () async {
    launch(endless: true);
    await service().openTracks(_songs, start: 2);
    backend.calls.clear();

    await service().next();

    expect(index(), 0);
    expect(backend.calls, ['open(a, next: b)']);
  });

  test('previous on the first track goes to the last when endless', () async {
    launch(endless: true);
    await service().openTracks(_songs);
    backend.calls.clear();

    await service().previous();

    expect(index(), 2);
    expect(backend.calls, ['open(c, next: null)']);
  });

  test('without the setting the ends stay put', () async {
    launch(endless: false);
    await service().openTracks(_songs, start: 2);
    backend.calls.clear();

    await service().next();
    expect(index(), 2);
    await service().jump(0);
    backend.calls.clear();
    await service().previous();
    expect(index(), 0);
    expect(backend.calls, isEmpty);
  });

  test('the repeat mode does not matter', () async {
    launch(endless: true);
    await service().openTracks(_songs, start: 2);
    await service().setRepeat(RepeatMode.one);
    await service().next();
    expect(index(), 0);
  });

  test('a one-track queue plays its track again', () async {
    launch(endless: true);
    await service().openTracks([_songs.first]);
    backend.calls.clear();

    await service().next();

    expect(index(), 0);
    expect(backend.calls, ['open(a, next: null)']);
  });

  test('next after the queue ran out starts it over', () async {
    launch(endless: true);
    await service().openTracks(_songs, start: 2);
    backend.emitCompleted.add(true);
    expect(container.read(playerServiceProvider).stopped, isTrue);

    await service().next();

    expect(index(), 0);
    expect(container.read(playerServiceProvider).playing, isTrue);
  });

  test('running out on its own still stops without repeat', () async {
    launch(endless: true);
    await service().openTracks(_songs, start: 2);
    backend.calls.clear();

    backend.emitCompleted.add(true);

    expect(container.read(playerServiceProvider).stopped, isTrue);
    expect(backend.calls.where((c) => c.startsWith('open(')), isEmpty);
  });

  test('the setting is read on each press', () async {
    launch(endless: false);
    await service().openTracks(_songs, start: 2);
    container
        .read(settingsProvider.notifier)
        .setPlayback(const PlaybackPrefs(infiniteQueue: true));

    await service().next();

    expect(index(), 0);
  });
}
