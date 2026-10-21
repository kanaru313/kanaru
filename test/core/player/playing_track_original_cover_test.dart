import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/original_cover_reader.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/playing_track_art.dart';
import 'package:kanaru/core/player/playing_track_original_cover.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:logging/logging.dart';

import 'fake_audio_backend.dart';
import 'fake_original_cover_reader.dart';

/// Stands in for the playing track's thumbnail, which a test can change.
class _Art extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? art) => state = art;
}

final _art = NotifierProvider<_Art, String?>(_Art.new);

Track _song(String uri) => Track(uri: uri, title: uri);

void main() {
  late FakeOriginalCoverReader reader;
  late ProviderContainer container;

  setUp(() {
    reader = FakeOriginalCoverReader();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        originalCoverReaderProvider.overrideWithValue(reader),
        playingTrackArtProvider.overrideWith((ref) => ref.watch(_art)),
      ],
    );
    container.listen(playerServiceProvider, (_, _) {});
    // Now Playing keeps the provider alive while it is open.
    container.listen(playingTrackOriginalCoverProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  PlayerService service() => container.read(playerServiceProvider.notifier);

  OriginalCover? current() =>
      container.read(playingTrackOriginalCoverProvider).value;

  Future<void> settle() => pumpEventQueue();

  test('nothing playing reads nothing', () async {
    await settle();

    expect(current(), isNull);
    expect(reader.reads, isEmpty);
  });

  test('reads the original of the playing local track', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    reader.bytes['/music/a.flac'] = bytes;

    await service().openTracks([_song('/music/a.flac')]);
    await settle();

    expect(reader.reads, ['/music/a.flac']);
    expect(current(), (uri: '/music/a.flac', bytes: bytes));
  });

  test('a file uri is read from its decoded path', () async {
    reader.bytes['/music/a b.flac'] = Uint8List.fromList([1]);

    await service().openTracks([_song('file:///music/a%20b.flac')]);
    await settle();

    expect(reader.reads, ['/music/a b.flac']);
    expect(current()?.uri, 'file:///music/a%20b.flac');
  });

  test('a track that is not a local file reads nothing', () async {
    await service().openTracks([_song('https://example.com/a.mp3')]);
    await settle();

    expect(current(), isNull);
    expect(reader.reads, isEmpty);
  });

  test('no bytes or empty bytes give no cover', () async {
    reader.bytes['/music/empty.flac'] = Uint8List(0);

    await service().openTracks([_song('/music/none.flac')]);
    await settle();
    expect(current(), isNull);

    await service().openTracks([_song('/music/empty.flac')]);
    await settle();
    expect(current(), isNull);
  });

  test('a failing read gives no cover, once, and is logged', () async {
    reader.throwOn.add('/music/a.flac');
    final records = <LogRecord>[];
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(sub.cancel);

    await service().openTracks([_song('/music/a.flac')]);
    await settle();

    expect(current(), isNull);
    expect(reader.reads, ['/music/a.flac'], reason: 'no retry');
    expect(records.where((r) => r.level == Level.WARNING), hasLength(1));
  });

  test('a slow read of the previous track never shows on the next', () async {
    final slow = Completer<Uint8List?>();
    reader.pending['/music/a.flac'] = slow;
    final b = Uint8List.fromList([9]);
    reader.bytes['/music/b.flac'] = b;

    await service().openTracks([_song('/music/a.flac')]);
    await settle();
    await service().openTracks([_song('/music/b.flac')]);
    slow.complete(Uint8List.fromList([1]));
    await settle();

    expect(current(), (uri: '/music/b.flac', bytes: b));
  });

  test('a new thumbnail reads the original again', () async {
    reader.bytes['/music/a.flac'] = Uint8List.fromList([1]);
    await service().openTracks([_song('/music/a.flac')]);
    await settle();
    expect(reader.reads, ['/music/a.flac']);

    container.read(_art.notifier).set('/covers/new.jpg');
    await settle();

    expect(reader.reads, ['/music/a.flac', '/music/a.flac']);
  });
}
