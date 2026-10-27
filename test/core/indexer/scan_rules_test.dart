import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/scan_rules.dart';
import 'package:kanaru/core/indexer/walk_audio_files.dart';
import 'package:kanaru/core/settings/library_scan_prefs.dart';

WalkedFile file(String path, {int mtime = 1, int size = 1000}) =>
    WalkedFile(path: path, mtimeMs: mtime, sizeBytes: size);

Set<String> paths(WalkResult r) => {for (final f in r.files) f.path};

void main() {
  const root = '/m';
  final walk = WalkResult(
    files: [
      file('/m/a.mp3'),
      file('/m/quiet/b.mp3'),
      file('/m/quiet/deep/c.mp3'),
      file('/m/loud/d.mp3', size: 10),
    ],
    unstattable: ['/m/quiet/e.mp3', '/m/loud/f.mp3'],
    unreadableDirs: ['/m/quiet/locked', '/m/other'],
    emptyDirs: ['/m/quiet/nas'],
    dirs: ['/m', '/m/quiet', '/m/quiet/deep', '/m/loud'],
    nomediaDirs: ['/m/quiet'],
  );

  test('no rule at work returns the walk itself', () {
    expect(
      identical(applyWalkRules(walk, root, const WalkRules()), walk),
      true,
    );
    // A nomedia folder does not count while the option is off.
    expect(
      identical(
        applyWalkRules(walk, root, const WalkRules(respectNomedia: false)),
        walk,
      ),
      isTrue,
    );
  });

  test(
    'nomedia drops the folder, its subtree and what cannot be listed in it',
    () {
      final result = applyWalkRules(
        walk,
        root,
        const WalkRules(respectNomedia: true),
      );

      expect(paths(result), {'/m/a.mp3', '/m/loud/d.mp3'});
      expect(result.unstattable, ['/m/loud/f.mp3']);
      expect(result.unreadableDirs, ['/m/other']);
      expect(result.emptyDirs, isEmpty);
      expect(result.dirs, ['/m', '/m/loud']);
      expect(result.filteredOut, 2 + 1, reason: '2 files and the folder');
    },
  );

  test('excluded folders below the root act like nomedia folders', () {
    final result = applyWalkRules(
      walk,
      root,
      const WalkRules(excludedPaths: ['/m/loud', '/elsewhere', '/m', '/mm']),
    );

    expect(paths(result), {
      '/m/a.mp3',
      '/m/quiet/b.mp3',
      '/m/quiet/deep/c.mp3',
    });
    expect(result.unstattable, ['/m/quiet/e.mp3']);
    expect(result.filteredOut, 1 + 1);
  });

  test('a folder whose name only starts like a blocked one stays', () {
    final result = applyWalkRules(
      WalkResult(files: [file('/m/quiet2/a.mp3')], dirs: ['/m', '/m/quiet2']),
      root,
      const WalkRules(excludedPaths: ['/m/quiet']),
    );

    expect(paths(result), {'/m/quiet2/a.mp3'});
    expect(result.filteredOut, 0);
  });

  test('an exclusion matches whole names, with % and _ taken literally', () {
    final result = applyWalkRules(
      WalkResult(
        files: [
          file('/m/Live/a.mp3'),
          file('/m/Live Albums/b.mp3'),
          file('/m/a_b/c.mp3'),
          file('/m/aXb/d.mp3'),
          file('/m/100%/e.mp3'),
          file('/m/100x/f.mp3'),
        ],
        dirs: ['/m'],
      ),
      root,
      const WalkRules(excludedPaths: ['/m/Live', '/m/a_b', '/m/100%']),
    );

    expect(paths(result), {
      '/m/Live Albums/b.mp3',
      '/m/aXb/d.mp3',
      '/m/100x/f.mp3',
    });
  });

  test('nested exclusions, and ones equal to or outside the root', () {
    final result = applyWalkRules(
      walk,
      root,
      const WalkRules(
        excludedPaths: ['/m/quiet', '/m/quiet/deep', '/m', '/x/m/loud'],
      ),
    );

    expect(paths(result), {'/m/a.mp3', '/m/loud/d.mp3'});
    expect(result.dirs, ['/m', '/m/loud']);
  });

  test('files under the minimum size are dropped and counted', () {
    final result = applyWalkRules(
      walk,
      root,
      const WalkRules(minFileSizeBytes: 1000),
    );

    expect(paths(result), {
      '/m/a.mp3',
      '/m/quiet/b.mp3',
      '/m/quiet/deep/c.mp3',
    }, reason: 'a file of exactly the minimum stays');
    expect(result.filteredOut, 1);
  });

  test('a recently changed file is deferred, not read and not deleted', () {
    final result = applyWalkRules(
      WalkResult(
        files: [file('/m/old.mp3', mtime: 100), file('/m/new.mp3', mtime: 900)],
      ),
      root,
      const WalkRules(),
      settledBeforeMs: 500,
    );

    expect(paths(result), {'/m/old.mp3'});
    expect(result.unstattable, ['/m/new.mp3']);
    expect(result.deferred, 1);
    expect(result.filteredOut, 0);
  });

  test('a file dated well in the future is read, not deferred', () {
    final result = applyWalkRules(
      WalkResult(
        files: [
          file('/m/now.mp3', mtime: 1002),
          file('/m/edge.mp3', mtime: 1005),
          file('/m/future.mp3', mtime: 1006),
          file('/m/hours.mp3', mtime: 1000 + 3600 * 1000),
        ],
      ),
      root,
      const WalkRules(),
      settledBeforeMs: 1000,
      settleUntilMs: 1005,
    );

    expect(paths(result), {'/m/future.mp3', '/m/hours.mp3'});
    expect(result.unstattable, ['/m/now.mp3', '/m/edge.mp3']);
    expect(result.deferred, 2);
  });

  test('ScanRules.from converts the stored options', () {
    final rules = ScanRules.from(
      const LibraryScanPrefs(
        respectNomedia: true,
        minFileSizeKb: 2,
        minDurationSeconds: 30,
      ),
      excluded: ['/m/x'],
    );

    expect(rules.walk.respectNomedia, isTrue);
    expect(rules.walk.minFileSizeBytes, 2048);
    expect(rules.walk.excludedPaths, ['/m/x']);
    expect(rules.minDurationMs, 30000);
    expect(const ScanRules().minDurationMs, 0);
  });

  group('hidden rules', () {
    test('ScanRules.from maps skipHiddenFolders, on by default', () {
      expect(
        ScanRules.from(const LibraryScanPrefs()).walk.skipHiddenFolders,
        isTrue,
      );
      expect(
        ScanRules.from(const LibraryScanPrefs(skipHiddenFolders: false))
            .walk
            .skipHiddenFolders,
        isFalse,
      );
    });

    test('a dot base name is barred in both modes', () {
      const stored = ['/r/._a.mp3', '/r/x/.b.mp3', '/r/c.mp3'];
      for (final skip in [true, false]) {
        expect(hiddenRowsBarred(stored, '/r', skipHiddenFolders: skip), 2);
      }
    });

    test('rows inside a dot folder are barred only while skipping', () {
      const stored = ['/r/.h/a.mp3', '/r/a/.h/b.mp3', '/r/a/c.mp3'];
      expect(hiddenRowsBarred(stored, '/r', skipHiddenFolders: true), 2);
      expect(hiddenRowsBarred(stored, '/r', skipHiddenFolders: false), 0);
    });

    test('a dot-named root is not a hidden folder below the root', () {
      expect(
        hiddenRowsBarred(
          ['/x/.music/a.mp3'],
          '/x/.music',
          skipHiddenFolders: true,
        ),
        0,
      );
    });

    test('hasHiddenSegmentBelow looks only below the root', () {
      expect(hasHiddenSegmentBelow('/r', '/r/.h'), isTrue);
      expect(hasHiddenSegmentBelow('/r', '/r/a/.h/b'), isTrue);
      expect(hasHiddenSegmentBelow('/r', '/r/a/b'), isFalse);
      expect(hasHiddenSegmentBelow('/r', '/r'), isFalse);
      expect(hasHiddenSegmentBelow('/x/.m', '/x/.m/a'), isFalse);
    });
  });
}
