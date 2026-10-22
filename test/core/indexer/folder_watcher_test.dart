import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/folder_watcher.dart';

import 'fake_watch_env.dart';

void main() {
  const root = '/music';
  late Watcher env;

  setUp(() => env = makeWatcher());
  tearDown(() => env.watcher.dispose());

  Future<void> emit(String dir, FileSystemEvent event) async {
    env.dirs.emit(dir, event);
    await settle();
  }

  Future<bool> triggers(FileSystemEvent event) async {
    env.watcher.sync([root]);
    final before = env.changes.length;
    await emit(root, event);
    env.timers.advance(quietFor);
    return env.changes.length > before;
  }

  group('event filter', () {
    test(
      'create: audio file, folder and .nomedia count; other files not',
      () async {
        expect(
          await triggers(FileSystemCreateEvent('$root/a.flac', false)),
          isTrue,
        );
        expect(
          await triggers(FileSystemCreateEvent('$root/.nomedia', false)),
          isTrue,
        );
        expect(
          await triggers(FileSystemCreateEvent('$root/cover.jpg', false)),
          isFalse,
        );
        expect(
          await triggers(FileSystemCreateEvent('$root/a.flac.part', false)),
          isFalse,
        );
      },
    );

    test('a new folder counts, a hidden one does not', () async {
      expect(await triggers(FileSystemCreateEvent('$root/new', true)), isTrue);
      expect(
        await triggers(FileSystemCreateEvent('$root/.cache', true)),
        isFalse,
      );
    });

    test('modify: only a content change of an audio file', () async {
      expect(
        await triggers(FileSystemModifyEvent('$root/a.mp3', false, true)),
        isTrue,
      );
      expect(
        await triggers(FileSystemModifyEvent('$root/a.mp3', false, false)),
        isFalse,
      );
      expect(
        await triggers(FileSystemModifyEvent('$root/a.txt', false, true)),
        isFalse,
      );
    });

    test('delete: audio file, .nomedia, or a watched folder', () async {
      env.watcher.sync([root, '$root/album']);
      await emit(root, FileSystemDeleteEvent('$root/a.ogg', false));
      env.timers.advance(quietFor);
      expect(env.changes, hasLength(1));

      await emit(root, FileSystemDeleteEvent('$root/readme.txt', false));
      env.timers.advance(quietFor);
      expect(env.changes, hasLength(1));

      // Dart reports a deleted folder as a file delete.
      await emit(root, FileSystemDeleteEvent('$root/album', false));
      env.timers.advance(quietFor);
      expect(env.changes, hasLength(2));
      expect(env.dirs.hasListener('$root/album'), isFalse);
    });

    test('move: a temporary name renamed to an audio name counts', () async {
      expect(
        await triggers(
          FileSystemMoveEvent('$root/.x.flac.AbC', false, '$root/x.flac'),
        ),
        isTrue,
      );
      expect(
        await triggers(
          FileSystemMoveEvent('$root/x.flac', false, '$root/x.flac.part'),
        ),
        isTrue,
      ); // the audio file is gone
      expect(
        await triggers(
          FileSystemMoveEvent('$root/a.txt', false, '$root/b.txt'),
        ),
        isFalse,
      );
    });

    test(
      'moving a folder out of the library counts and drops its watches',
      () async {
        env.watcher.sync([root, '$root/a', '$root/a/b']);
        await emit(root, FileSystemMoveEvent('$root/a', true, null));
        env.timers.advance(quietFor);
        expect(env.changes, hasLength(1));
        expect(env.dirs.hasListener('$root/a'), isFalse);
        expect(env.dirs.hasListener('$root/a/b'), isFalse);
        expect(env.dirs.hasListener(root), isTrue);
      },
    );
  });

  group('timing', () {
    test('scans once after 3 s of quiet', () async {
      env.watcher.sync([root]);
      await emit(root, FileSystemCreateEvent('$root/a.mp3', false));
      env.timers.advance(const Duration(seconds: 2));
      await emit(root, FileSystemCreateEvent('$root/b.mp3', false));
      env.timers.advance(const Duration(seconds: 2));
      expect(env.changes, isEmpty);
      env.timers.advance(const Duration(seconds: 1));
      expect(env.changes, hasLength(1));
    });

    test('scans at the latest 60 s after the first event of a burst', () async {
      env.watcher.sync([root]);
      for (var i = 0; i < 40; i++) {
        await emit(root, FileSystemCreateEvent('$root/$i.mp3', false));
        env.timers.advance(const Duration(seconds: 2));
      }
      expect(env.changes, hasLength(1)); // at 60 s, while events keep coming
    });

    test('a failed scan delays the next one by 60 s', () async {
      env.watcher.sync([root]);
      env.watcher.scanEnded(failed: true, deferred: 0);
      await emit(root, FileSystemCreateEvent('$root/a.mp3', false));
      env.timers.advance(const Duration(seconds: 30));
      expect(env.changes, isEmpty);
      env.timers.advance(const Duration(seconds: 30));
      expect(env.changes, hasLength(1));
    });

    test('files still being written get another scan', () async {
      env.watcher.sync([root]);
      env.watcher.scanEnded(failed: false, deferred: 2);
      env.timers.advance(quietFor);
      expect(env.changes, hasLength(1));
      env.watcher.scanEnded(failed: false, deferred: 0);
      env.timers.advance(const Duration(minutes: 5));
      expect(env.changes, hasLength(1));
    });

    test('files that never settle slow down to one scan a minute', () async {
      env.watcher.sync([root]);
      for (var i = 0; i < 5; i++) {
        env.watcher.scanEnded(failed: false, deferred: 1);
        env.timers.advance(quietFor);
      }
      expect(env.changes, hasLength(5));
      env.watcher.scanEnded(failed: false, deferred: 1);
      env.timers.advance(quietFor);
      expect(env.changes, hasLength(5));
      env.timers.advance(const Duration(seconds: 57));
      expect(env.changes, hasLength(6));
    });

    test('dispose cancels timers and watches', () async {
      env.watcher.sync([root]);
      await emit(root, FileSystemCreateEvent('$root/a.mp3', false));
      await env.watcher.dispose();
      env.timers.advance(const Duration(minutes: 2));
      expect(env.changes, isEmpty);
      expect(env.dirs.anyListener, isFalse);
      expect(env.watcher.status, WatchStatus.off);
    });
  });

  group('sync', () {
    test('watches new folders, lets go of the others', () async {
      env.watcher.sync([root, '$root/a']);
      env.watcher.sync([root, '$root/b']);
      expect(env.dirs.hasListener('$root/a'), isFalse);
      expect(env.dirs.hasListener('$root/b'), isTrue);
      expect(env.dirs.opened.where((d) => d == root), hasLength(1));
    });

    test('more folders than the budget: none watched, limit reached', () async {
      env = makeWatcher(maxWatches: 2);
      env.watcher.sync([root, '$root/a', '$root/b']);
      expect(env.dirs.opened, isEmpty);
      expect(env.watcher.status, WatchStatus.limitReached);
    });

    test(
      'out of watches at the k-th folder: all cancelled, nothing scanned',
      () async {
        env.dirs.failing['$root/c'] = outOfWatches('$root/c');
        final statuses = <WatchStatus>[];
        env.watcher.statusChanges.listen(statuses.add);
        env.watcher.sync([root, '$root/a', '$root/b', '$root/c', '$root/d']);
        await settle();
        await emit(
          root,
          FileSystemCreateEvent('$root/a.mp3', false),
        ).catchError((_) {});
        env.timers.advance(const Duration(minutes: 2));
        expect(env.watcher.status, WatchStatus.limitReached);
        expect(statuses, [WatchStatus.limitReached]);
        expect(env.dirs.anyListener, isFalse);
        expect(env.changes, isEmpty);
        expect(env.timers.active, 0);
        // Stays until a new watcher is made.
        env.watcher.sync([root]);
        expect(env.dirs.hasListener(root), isFalse);
      },
    );

    test(
      'a folder that cannot be read is dropped alone, until the next sync',
      () async {
        env.dirs.failing['$root/locked'] = denied('$root/locked');
        env.watcher.sync([root, '$root/locked']);
        await settle();
        expect(env.watcher.status, WatchStatus.watching);
        expect(env.dirs.hasListener(root), isTrue);
        expect(env.watcher.watchedCount, 1);
        env.timers.advance(const Duration(minutes: 2));
        expect(env.changes, isEmpty); // the close after the error is no change
        // Not tried again within the same round.
        env.dirs.failing.clear();
        await emit(root, FileSystemCreateEvent('$root/x.txt', false));
        expect(env.dirs.opened.where((d) => d == '$root/locked'), hasLength(1));
        // The next sync tries again.
        env.watcher.sync([root, '$root/locked']);
        await settle();
        expect(env.dirs.opened.where((d) => d == '$root/locked'), hasLength(2));
        expect(env.dirs.hasListener('$root/locked'), isTrue);
      },
    );

    test('a watched folder that closes by itself is a change', () async {
      env.watcher.sync([root, '$root/a']);
      await env.dirs.controllers['$root/a']!.close();
      await settle();
      env.timers.advance(quietFor);
      expect(env.changes, hasLength(1));
      expect(env.watcher.watchedCount, 1);
    });
  });

  group('no scan loops', () {
    test(
      'a deleted root: every watch closes, one scan, then silence',
      () async {
        final dirs = [root, for (var i = 0; i < 20; i++) '$root/d$i'];
        env.watcher.sync(dirs);
        for (final dir in dirs) {
          await env.dirs.controllers[dir]!.close();
        }
        await settle();
        env.timers.advance(quietFor);
        expect(env.changes, hasLength(1));
        // The scan reports the root missing; its folders are published empty.
        env.watcher.scanEnded(failed: false, deferred: 0);
        env.watcher.sync(const []);
        env.timers.advance(const Duration(minutes: 5));
        expect(env.changes, hasLength(1));
        expect(env.dirs.anyListener, isFalse);
      },
    );

    test(
      'a renamed root gives events once; after the empty sync no more',
      () async {
        env.watcher.sync([root, '$root/a']);
        await emit(root, FileSystemDeleteEvent('$root/a', false));
        env.timers.advance(quietFor);
        expect(env.changes, hasLength(1));
        env.watcher.scanEnded(failed: false, deferred: 0);
        env.watcher.sync(const []);
        env.timers.advance(const Duration(minutes: 5));
        expect(env.changes, hasLength(1));
      },
    );
  });
}
