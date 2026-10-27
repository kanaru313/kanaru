import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_root_queries.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/core/indexer/tag_reader.dart';
import 'package:kanaru/core/indexer/walk_audio_files.dart';

import 'fake_tag_reader.dart';

/// Holds the first read until [release] is called.
class _GatedTagReader extends FakeTagReader {
  final entered = Completer<void>();
  final _gate = Completer<void>();
  bool gateNext = false;

  void release() => _gate.complete();

  @override
  Future<List<TrackTags>> readBatch(List<String> paths) async {
    if (gateNext && !entered.isCompleted) {
      entered.complete();
      await _gate.future;
    }
    return super.readBatch(paths);
  }
}

void main() {
  late Directory tmp;
  late String base, rootA, rootB;
  late LibraryDatabase db;
  late _GatedTagReader reader;
  late ProviderContainer container;
  Completer<void>? walkGate;
  late Completer<void> walkEntered;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('indexer_removal_test');
    base = tmp.resolveSymbolicLinksSync();
    rootA = '$base/a';
    rootB = '$base/b';
    for (final root in [rootA, rootB]) {
      File('$root/${root.split('/').last}.mp3')
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
    }
    db = LibraryDatabase(NativeDatabase.memory());
    reader = _GatedTagReader();
    walkGate = null;
    walkEntered = Completer<void>();
    container = ProviderContainer(
      overrides: [
        ...LibraryStartup(db: db).overrides,
        tagReaderProvider.overrideWithValue(reader),
        rootWalkerProvider.overrideWithValue((
          root, {
          required skipHiddenFolders,
        }) async {
          final gate = walkGate;
          if (gate != null && root == rootA) {
            walkGate = null;
            if (!walkEntered.isCompleted) walkEntered.complete();
            await gate.future;
          }
          return walkAudioFilesInIsolate(
            root,
            skipHiddenFolders: skipHiddenFolders,
          );
        }),
      ],
    );
    await db.addRoots([rootA, rootB], now: 1);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  IndexerState state() => container.read(libraryIndexerProvider);
  Future<List<String>> paths() async =>
      [for (final t in await db.select(db.tracks).get()) t.path]..sort();

  Future<void> removeA() async {
    final a = (await db.roots()).firstWhere((r) => r.path == rootA);
    await db.removeRoot(a.id);
  }

  test(
    'a root removed while its folder is walked is dropped quietly',
    () async {
      final gate = walkGate = Completer<void>();
      final done = container.read(libraryIndexerProvider.notifier).scan();
      await walkEntered.future;
      await removeA();
      gate.complete();
      await done;

      expect(state(), isA<IndexerFinished>());
      final summary = (state() as IndexerFinished).summary;
      expect(summary.skippedRoots, isEmpty);
      expect(summary.added, 1, reason: 'only b');
      expect(await paths(), ['$rootB/b.mp3']);
    },
  );

  test('a root removed while its tags are read leaves no rows', () async {
    reader.gateNext = true;
    final done = container.read(libraryIndexerProvider.notifier).scan();
    await reader.entered.future;
    await removeA();
    reader.release();
    await done;

    expect(state(), isA<IndexerFinished>());
    expect((state() as IndexerFinished).summary.skippedRoots, isEmpty);
    expect(await paths(), ['$rootB/b.mp3']);
  });

  test('a root replaced mid-scan is scanned by the follow-up pass', () async {
    final rootC = '$base/c';
    File('$rootC/c.mp3')
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
    final gate = walkGate = Completer<void>();
    final indexer = container.read(libraryIndexerProvider.notifier);
    final done = indexer.scan();
    await walkEntered.future;
    expect(walkGate, isNull, reason: 'the scan is inside a\'s walk');

    final a = (await db.roots()).firstWhere((r) => r.path == rootA);
    final result = await container
        .read(libraryRootsControllerProvider)
        .replaceRoot(a.id, rootC);
    expect(result.ok, isTrue);
    final followUp = indexer.scan();
    gate.complete();
    await Future.wait([done, followUp]);

    expect(state(), isA<IndexerFinished>());
    expect(await paths(), ['$rootB/b.mp3', '$rootC/c.mp3']);
  });
}
