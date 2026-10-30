import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_reader.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_zip_reader.dart';

import 'package_test_helpers.dart';

void expectKind(Uint8List zip, PluginPackageProblemKind kind) {
  expect(
    () => readPluginZip(zip),
    throwsA(isA<PluginPackageProblem>().having((p) => p.kind, 'kind', kind)),
  );
}

void main() {
  group('safe names', () {
    for (final name in [
      '../evil.js',
      'src/../../evil.js',
      '/etc/passwd',
      r'src\search.js',
      'C:/win.js',
      'c:evil',
      'src/a\u0000.js',
    ]) {
      test('rejects "${name.replaceAll('\u0000', r'\0')}"', () {
        expectKind(
          validZip(extra: {name: 'x'}),
          PluginPackageProblemKind.unsafeEntry,
        );
      });
    }

    test('rejects a symlink entry', () {
      final zip = validZip(extra: {'src/link.js': 'search.js'});
      // Re-encode with the symlink mode set on that entry.
      final archive = ZipDecoder().decodeBytes(zip);
      final rebuilt = buildZip(
        {for (final f in archive) f.name: f.content as List<int>},
        modes: {'src/link.js': 0xa1ff},
      );
      expectKind(rebuilt, PluginPackageProblemKind.unsafeEntry);
    });

    test('rejects names equal ignoring case', () {
      expectKind(
        validZip(extra: {'src/Search.JS': 'x', 'src/search.js': 'y'}),
        PluginPackageProblemKind.unsafeEntry,
      );
    });
  });

  group('limits', () {
    test('rejects a file over 5 MiB before decoding', () {
      expectKind(
        Uint8List(5 * 1024 * 1024 + 1),
        PluginPackageProblemKind.tooLarge,
      );
    });

    test('rejects bytes that are not a zip', () {
      expectKind(
        Uint8List.fromList([1, 2, 3, 4]),
        PluginPackageProblemKind.notZip,
      );
    });

    test('rejects 51 entries, accepts 50', () {
      Map<String, Object> many(int n) => {
        for (var i = 0; i < n; i++) 'other/$i.txt': 'x',
      };
      // 3 entries are the required ones.
      expectKind(
        validZip(extra: many(48)),
        PluginPackageProblemKind.tooManyEntries,
      );
      expect(readPluginZip(validZip(extra: many(47))).scripts, hasLength(2));
    });

    test('rejects a declared total over 5 MiB even for ignored entries', () {
      final zip = validZip(extra: {'big.bin': Uint8List(6 * 1024 * 1024)});
      expectKind(zip, PluginPackageProblemKind.tooLarge);
    });

    test('stops the entry whose header declares less than it inflates', () {
      // 3 MiB of zeros: about 3 KB zipped. Only this entry lies.
      final zip = patchEntry(
        validZip(extra: {'src/big.js': Uint8List(3 * 1024 * 1024)}),
        'src/big.js',
        size: 100,
      );
      expect(
        () => readPluginZip(zip),
        throwsA(
          isA<PluginPackageProblem>()
              .having((p) => p.kind, 'kind', PluginPackageProblemKind.tooLarge)
              .having((p) => p.detail, 'detail', 'src/big.js'),
        ),
      );
    });

    test('never inflates an ignored entry that declares a small size', () {
      final zip = patchEntry(
        validZip(extra: {'big.bin': Uint8List(3 * 1024 * 1024)}),
        'big.bin',
        size: 100,
      );
      expect(readPluginZip(zip).scripts, hasLength(2));
    });

    test('rejects a script over 1 MiB', () {
      final zip = validZip(extra: {'src/big.js': Uint8List(1024 * 1024 + 1)});
      expectKind(zip, PluginPackageProblemKind.tooLarge);
    });

    test('rejects a manifest over 64 KiB', () {
      final zip = buildZip({'plugin.json': Uint8List(64 * 1024 + 1)});
      expectKind(zip, PluginPackageProblemKind.tooLarge);
    });

    test('rejects an entry that declares more than the data holds', () {
      final zip = patchEntry(validZip(), 'src/search.js', size: 5000);
      expectKind(zip, PluginPackageProblemKind.notZip);
    });
  });

  group('central directory', () {
    test('many records on one huge local header end fast', () {
      final watch = Stopwatch()..start();
      expectKind(
        amplifiedZip(records: 10000),
        PluginPackageProblemKind.tooManyEntries,
      );
      expect(watch.elapsedMilliseconds, lessThan(500));
    });

    test('thousands of records with a lying end record are refused fast', () {
      expectKind(
        amplifiedZip(records: 5000, announced: 3, localNameLength: 10),
        PluginPackageProblemKind.notZip,
      );
    });

    test('records sharing one local header are refused', () {
      expectKind(
        amplifiedZip(records: 3, localNameLength: 10),
        PluginPackageProblemKind.notZip,
      );
    });

    test('an over-long local name is refused', () {
      expectKind(amplifiedZip(records: 1), PluginPackageProblemKind.notZip);
    });

    test('an end record announcing fewer entries than the directory holds', () {
      expectKind(
        patchEndRecord(validZip(), totalEntries: 2, entriesOnDisk: 2),
        PluginPackageProblemKind.notZip,
      );
    });

    test('an end record announcing more entries than the directory holds', () {
      expectKind(
        patchEndRecord(validZip(), totalEntries: 4, entriesOnDisk: 4),
        PluginPackageProblemKind.notZip,
      );
    });

    test('a directory size that does not match', () {
      final zip = validZip();
      final size = ByteData.sublistView(zip)
          .getUint32(zip.length - 10, Endian.little);
      expectKind(
        patchEndRecord(zip, directorySize: size - 1),
        PluginPackageProblemKind.notZip,
      );
    });

    test('zip64 markers in the end record are refused', () {
      expectKind(
        patchEndRecord(validZip(), totalEntries: 0xffff, entriesOnDisk: 0xffff),
        PluginPackageProblemKind.notZip,
      );
      expectKind(
        patchEndRecord(validZip(), directoryOffset: 0xffffffff),
        PluginPackageProblemKind.notZip,
      );
    });

    test('a zip64 locator before the end record is refused', () {
      final zip = validZip();
      final end = zip.length - 22;
      final locator = Uint8List(20)..setAll(0, [0x50, 0x4b, 0x06, 0x07]);
      final withLocator = Uint8List.fromList([
        ...zip.sublist(0, end),
        ...locator,
        ...zip.sublist(end),
      ]);
      expectKind(withLocator, PluginPackageProblemKind.notZip);
    });

    test('a fake end record inside the real comment is refused fast', () {
      // Real end record with a comment holding a second end record that
      // points at thousands of hidden central records, plus one extra byte.
      final hidden = amplifiedZip(records: 10000, localNameLength: 10);
      final fake = hidden.sublist(hidden.length - 22);
      final real = validZip();
      final end = real.length - 22;
      final comment = Uint8List.fromList([...fake, 0]);
      final forged = Uint8List.fromList([
        ...real.sublist(0, end),
        ...real.sublist(end, end + 20),
        comment.length & 0xff,
        comment.length >> 8,
        ...comment,
      ]);
      final watch = Stopwatch()..start();
      expectKind(forged, PluginPackageProblemKind.notZip);
      expect(watch.elapsedMilliseconds, lessThan(500));
    });

    test('all-ones sizes or offsets in a central record are refused', () {
      for (final field in [20, 24, 42]) {
        final zip = validZip();
        final start = ByteData.sublistView(zip)
            .getUint32(zip.length - 6, Endian.little);
        ByteData.sublistView(zip)
            .setUint32(start + field, 0xffffffff, Endian.little);
        expectKind(zip, PluginPackageProblemKind.notZip);
      }
    });

    test('bytes after the end record are refused', () {
      expectKind(
        Uint8List.fromList([...validZip(), 0, 0]),
        PluginPackageProblemKind.notZip,
      );
    });

    test('a bad central record fails the whole package', () {
      final zip = validZip();
      final data = ByteData.sublistView(zip);
      final start = data.getUint32(zip.length - 6, Endian.little);
      final broken = Uint8List.fromList(zip)..[start + 1] = 0;
      expectKind(broken, PluginPackageProblemKind.notZip);
    });
  });

  group('entry kinds', () {
    test('encrypted entry', () {
      expectKind(
        patchEntry(validZip(), 'src/search.js', flags: 1),
        PluginPackageProblemKind.notZip,
      );
    });

    test('unsupported compression methods', () {
      for (final method in [12, 14, 93, 98]) {
        expectKind(
          patchEntry(validZip(), 'src/search.js', method: method),
          PluginPackageProblemKind.notZip,
        );
      }
    });

    test('checksum mismatch', () {
      expectKind(
        patchEntry(validZip(), 'src/search.js', crc: 1234),
        PluginPackageProblemKind.notZip,
      );
    });

    test('an entry with a data descriptor flag is still read', () {
      final zip = patchEntry(validZip(), 'src/search.js', flags: 8);
      expect(readPluginZip(zip).scripts, hasLength(2));
    });

    test('a symlink on an ignored entry still refuses the package', () {
      final zip = patchEntry(
        validZip(extra: {'notes.txt': 'x'}),
        'notes.txt',
        versionMadeBy: 0x031e,
        externalAttributes: 0xa1ff << 16,
      );
      expectKind(zip, PluginPackageProblemKind.unsafeEntry);
    });

    test('names equal but for a trailing slash', () {
      expectKind(
        validZip(extra: {'src/': '', 'src': 'x'}),
        PluginPackageProblemKind.unsafeEntry,
      );
    });

    test(
      'a bad icon (cannot be inflated, lying size) is dropped, not fatal',
      () {
        final base = validZip(extra: {'icon.png': pngHeader(8, 8)});
        for (final zip in [
          patchEntry(base, 'icon.png', crc: 99),
          patchEntry(base, 'icon.png', size: 40000),
          patchEntry(base, 'icon.png', flags: 1),
        ]) {
          final contents = readPluginZip(zip);
          expect(contents.icon, isNull);
          expect(contents.iconProblem, isNotNull);
        }
      },
    );

    test('an icon without an IHDR chunk is dropped', () {
      final icon = pngHeader(8, 8)..[13] = 0x58;
      final contents = readPluginZip(validZip(extra: {'icon.png': icon}));
      expect(contents.icon, isNull);
      expect(contents.iconProblem, 'IHDR chunk missing');
    });
  });

  group('layout', () {
    test('rejects a package without plugin.json', () {
      expectKind(
        buildZip({'src/search.js': 'x'}),
        PluginPackageProblemKind.missingManifest,
      );
    });

    test('strips one top-level folder', () {
      final contents = readPluginZip(validZip(prefix: 'myplugin/'));
      expect(
        contents.scripts.keys,
        unorderedEquals(['search.js', 'lyrics.js']),
      );
    });

    test('does not strip when an entry is outside the folder', () {
      final zip = buildZip({'a/plugin.json': '{}', 'b/readme.txt': 'x'});
      expectKind(zip, PluginPackageProblemKind.missingManifest);
    });

    test('does not strip a nested folder', () {
      expectKind(
        validZip(prefix: 'a/b/'),
        PluginPackageProblemKind.missingManifest,
      );
    });

    test('keeps only whitelisted entries', () {
      final contents = readPluginZip(
        validZip(
          extra: {
            'readme.md': 'hi',
            'src/sub/deep.js': 'x',
            'src/notes.txt': 'x',
            'src/bad name.js': 'x',
            'src/': '',
          },
        ),
      );
      expect(
        contents.scripts.keys,
        unorderedEquals(['search.js', 'lyrics.js']),
      );
    });

    test('reads stored (uncompressed) entries', () {
      final archive = Archive()
        ..add(ArchiveFile.bytes('plugin.json', [1, 2, 3]));
      final zip = Uint8List.fromList(
        ZipEncoder().encodeBytes(archive, level: 0),
      );
      expect(readPluginZip(zip).manifest, [1, 2, 3]);
    });
  });
}
