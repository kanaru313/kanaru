import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/tag_reader.dart';
import 'package:kanaru/core/open_files/open_files_provider.dart';
import 'package:kanaru/core/open_files/open_files_service.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:logging/logging.dart';

import '../indexer/fake_tag_reader.dart';
import '../player/fake_audio_backend.dart';

/// Reader whose calls wait for [release]; counts the calls it received.
class _HangingReader extends FakeTagReader {
  final gate = Completer<void>();

  @override
  Future<List<TrackTags>> readBatch(List<String> paths) async {
    final tags = await super.readBatch(paths);
    await gate.future;
    return tags;
  }
}

/// Reader that also reports an album and a year.
class _AlbumReader extends FakeTagReader {
  @override
  Future<List<TrackTags>> readBatch(List<String> paths) async => [
    for (final t in await super.readBatch(paths))
      TrackTags(
        path: t.path,
        error: t.error,
        title: t.title,
        artist: t.artist,
        album: ' Blue ',
        year: 1999,
        durationMs: t.durationMs,
      ),
  ];
}

void main() {
  late Directory dir;
  late FakeAudioBackend backend;
  late FakeTagReader reader;
  late ProviderContainer container;

  String file(String name) {
    final f = File('${dir.path}/$name')..writeAsStringSync('x');
    return f.path;
  }

  List<String> titles() => [
    for (final t in container.read(playerServiceProvider).queue.tracks) t.title,
  ];

  void build({FakeTagReader? tags, Duration? timeout}) {
    reader = tags ?? FakeTagReader();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        tagReaderProvider.overrideWithValue(reader),
        openFilesServiceProvider.overrideWith(
          (ref) => OpenFilesService(
            ref,
            tagTimeout: timeout ?? const Duration(seconds: 5),
          ),
        ),
      ],
    );
    container.listen(playerServiceProvider, (_, _) {});
  }

  setUp(() {
    Logger.root.level = Level.OFF;
    dir = Directory(
      Directory.systemTemp
          .createTempSync('kanaru_open_')
          .resolveSymbolicLinksSync(),
    );
    backend = FakeAudioBackend();
    build();
  });

  tearDown(() {
    container.dispose();
    dir.deleteSync(recursive: true);
  });

  test('plays the files in the order given, with their tags', () async {
    final a = file('a.flac'), b = file('b c.mp3'), c = file('c.ogg');

    final opened = await container.read(openFilesServiceProvider).open([
      c,
      a,
      b,
    ]);

    expect(opened, 3);
    expect(titles(), ['C.OGG', 'A.FLAC', 'B C.MP3']);
    final track = container.read(playerServiceProvider).queue.tracks.first;
    expect(track.uri, c);
    expect(track.artist, 'Artist');
    expect(track.duration, const Duration(seconds: 1));
    expect(track.artUri, isNull);
  });

  test('carries the album and year from the tags', () async {
    build(tags: _AlbumReader());
    await container.read(openFilesServiceProvider).open([file('a.flac')]);

    final track = container.read(playerServiceProvider).queue.tracks.single;
    expect(track.album, 'Blue');
    expect(track.year, 1999);
  });

  test('has no album without tags', () async {
    await container.read(openFilesServiceProvider).open([file('a.flac')]);

    final track = container.read(playerServiceProvider).queue.tracks.single;
    expect(track.album, isNull);
    expect(track.year, isNull);
  });

  test('drops anything that is not a local audio file', () async {
    final good = file('good.mp3');
    file('notes.txt');
    final opened = await container.read(openFilesServiceProvider).open([
      'http://example.com/a.mp3',
      'edl://%5,/x.mp3',
      'av://lavfi:sine',
      '${dir.path}/notes.txt',
      '${dir.path}/missing.mp3',
      Uri.file(good).toString(),
    ]);

    expect(opened, 1);
    expect(backend.calls, hasLength(1));
    expect(container.read(playerServiceProvider).queue.tracks.single.uri, good);
    for (final batch in reader.batches) {
      expect(batch.every((p) => p.startsWith('/')), isTrue);
    }
  });

  test('leaves the queue alone when nothing passes', () async {
    final a = file('a.mp3');
    final svc = container.read(openFilesServiceProvider);
    await svc.open([a]);
    backend.calls.clear();

    expect(await svc.open(['http://x/a.mp3', '${dir.path}/no.mp3']), 0);

    expect(titles(), ['A.MP3']);
    expect(backend.calls, isEmpty);
  });

  test('a symlinked folder gives the canonical uri', () async {
    final real = Directory('${dir.path}/real')..createSync();
    File('${real.path}/a.flac').writeAsStringSync('x');
    final link = Link('${dir.path}/link')..createSync(real.path);

    await container.read(openFilesServiceProvider).open([
      '${link.path}/a.flac',
    ]);

    expect(
      container.read(playerServiceProvider).queue.tracks.single.uri,
      '${real.path}/a.flac',
    );
  });

  test('caps one request at 1000 paths', () async {
    final paths = [for (var i = 0; i < 1001; i++) '${dir.path}/t$i.mp3'];
    for (final p in paths) {
      File(p).writeAsStringSync('x');
    }

    final opened = await container.read(openFilesServiceProvider).open(paths);

    expect(opened, 1000);
    expect(container.read(playerServiceProvider).queue.tracks.length, 1000);
    // Batches stay within the indexer's batch size.
    expect(reader.batches.every((b) => b.length <= 512), isTrue);
  });

  test('a newer request replaces one still reading tags', () async {
    container.dispose();
    final hanging = _HangingReader();
    build(tags: hanging, timeout: const Duration(seconds: 30));
    final first = file('first.mp3'), second = file('second.mp3');
    final svc = container.read(openFilesServiceProvider);

    final one = svc.open([first]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final two = svc.open([second]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    hanging.gate.complete();

    expect(await one, 0);
    expect(await two, 1);
    expect(titles(), ['SECOND.MP3']);
  });

  test(
    'a request where nothing passes does not cancel one in flight',
    () async {
      container.dispose();
      final hanging = _HangingReader();
      build(tags: hanging, timeout: const Duration(seconds: 30));
      final good = file('good.mp3');
      final svc = container.read(openFilesServiceProvider);

      final one = svc.open([good]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await svc.open(['${dir.path}/typo.mp3', 'http://x/a.mp3']), 0);
      hanging.gate.complete();

      expect(await one, 1);
      expect(titles(), ['GOOD.MP3']);
    },
  );

  test('a newer request wins while an older one still checks paths', () async {
    final many = [for (var i = 0; i < 200; i++) file('m$i.mp3')];
    final newest = file('newest.mp3');
    final svc = container.read(openFilesServiceProvider);

    final older = svc.open(many);
    final newer = svc.open([newest]);

    expect(await older, 0);
    expect(await newer, 1);
    expect(titles(), ['NEWEST.MP3']);
    expect(
      reader.batches.expand((b) => b),
      isNot(contains(many.first)),
      reason: 'the older request never reached the tag reader',
    );
  });

  test('a slow tag batch plays by file name and blocks later reads', () async {
    container.dispose();
    final hanging = _HangingReader();
    build(tags: hanging, timeout: const Duration(milliseconds: 10));
    final a = file('a.mp3'), b = file('b.mp3');
    final svc = container.read(openFilesServiceProvider);

    expect(await svc.open([a]), 1);
    expect(titles(), ['a']);
    expect(hanging.batches, hasLength(1));

    expect(await svc.open([b]), 1);
    expect(titles(), ['b']);
    expect(hanging.batches, hasLength(1), reason: 'no read while stuck');

    hanging.gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await svc.open([a]), 1);
    expect(hanging.batches, hasLength(2), reason: 'reads again once free');
  });

  test('a reader that throws still plays the files by name', () async {
    reader.throwOnRead = StateError('no native library');
    final a = file('a.mp3');

    expect(await container.read(openFilesServiceProvider).open([a]), 1);
    expect(titles(), ['a']);
  });
}
