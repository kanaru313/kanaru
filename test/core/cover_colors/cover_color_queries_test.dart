import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/cover_colors/cover_color_extractor.dart';
import 'package:kanaru/core/cover_colors/cover_palette.dart';
import 'package:kanaru/core/database/cover_color_queries.dart';
import 'package:kanaru/core/database/library_database.dart';

import 'fake_cover_color_extractor.dart';

void main() {
  late LibraryDatabase db;
  late int rootA, rootB;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    [rootA, rootB] = await db.addRoots(['/a', '/b'], now: 1);
  });
  tearDown(() => db.close());

  Future<void> track(int root, String name, String? key) => db.upsertTracks([
    TracksCompanion.insert(
      rootId: root,
      path: '/${root == rootA ? 'a' : 'b'}/$name',
      mtimeMs: 1,
      sizeBytes: 1,
      title: name,
      addedAt: 1,
      updatedAt: 1,
      coverKey: Value(key),
    ),
  ]);

  Future<List<String>> storedKeys() async =>
      [for (final row in await db.select(db.coverColors).get()) row.coverKey]
        ..sort();

  test('stored colors read back under the current version', () async {
    final key = keyFor(1);
    await db.upsertCoverColors([
      CoverColorSample(
        key: key,
        ok: true,
        seed: 0xFFCC2233,
        palette: [0xFFCC2233, 0xFF112233],
      ),
    ]);
    final row = await db.select(db.coverColors).getSingle();
    expect(row.palette, 'ffcc2233,ff112233');
    expect(row.algoVersion, coverColorAlgoVersion);
    expect(
      await db.coverPaletteOf(key),
      const CoverPalette(
        seed: Color(0xFFCC2233),
        colors: [Color(0xFFCC2233), Color(0xFF112233)],
      ),
    );
  });

  test('failed samples are not stored; a later write replaces', () async {
    final key = keyFor(1);
    await db.upsertCoverColors([
      CoverColorSample(key: keyFor(2), ok: false),
      sampleFor(key, seed: 0xFF000001),
    ]);
    await db.upsertCoverColors([sampleFor(key, seed: 0xFF000002)]);
    expect(await storedKeys(), [key]);
    expect((await db.coverPaletteOf(key))!.seed, const Color(0xFF000002));
  });

  test('a gray cover reads with no seed', () async {
    final key = keyFor(1);
    await db.upsertCoverColors([sampleFor(key, seed: 0)]);
    final palette = await db.coverPaletteOf(key);
    expect(palette!.seed, isNull);
    expect(palette.colors, isNotEmpty);
  });

  test('a row of another version or a damaged row counts as missing', () async {
    await track(rootA, 'old.mp3', keyFor(1));
    await track(rootA, 'bad.mp3', keyFor(2));
    await track(rootA, 'good.mp3', keyFor(3));
    await db
        .into(db.coverColors)
        .insert(
          CoverColorsCompanion.insert(
            coverKey: keyFor(1),
            seed: 0xFFCC2233,
            palette: 'ffcc2233',
            algoVersion: coverColorAlgoVersion - 1,
          ),
        );
    await db
        .into(db.coverColors)
        .insert(
          CoverColorsCompanion.insert(
            coverKey: keyFor(2),
            seed: 0xFFCC2233,
            palette: 'FFCC2233',
            algoVersion: coverColorAlgoVersion,
          ),
        );
    await db.upsertCoverColors([sampleFor(keyFor(3))]);

    expect(await db.coverPaletteOf(keyFor(1)), isNull);
    expect(await db.coverPaletteOf(keyFor(2)), isNull);
    expect(await db.coverPaletteOf(keyFor(3)), isNotNull);
    expect(await db.coverKeysNeedingColors([rootA]), [keyFor(1), keyFor(2)]);
  });

  test(
    'keys needing colors: only the given roots, no NULL, no dupes',
    () async {
      await track(rootA, '1.mp3', keyFor(5));
      await track(rootA, '2.mp3', keyFor(5));
      await track(rootA, '3.mp3', keyFor(4));
      await track(rootA, '4.mp3', null);
      await track(rootB, '5.mp3', keyFor(6));
      expect(await db.coverKeysNeedingColors([rootA]), [keyFor(4), keyFor(5)]);
      expect(await db.coverKeysNeedingColors([rootA, rootB]), [
        keyFor(4),
        keyFor(5),
        keyFor(6),
      ]);
      expect(await db.coverKeysNeedingColors([]), isEmpty);
      await db.upsertCoverColors([sampleFor(keyFor(5))]);
      expect(await db.coverKeysNeedingColors([rootA]), [keyFor(4)]);
    },
  );

  test('orphan colors go even when some track has no cover', () async {
    await track(rootA, 'used.mp3', keyFor(1));
    await track(rootA, 'none.mp3', null);
    await db.upsertCoverColors([sampleFor(keyFor(1)), sampleFor(keyFor(2))]);
    expect(await db.deleteOrphanCoverColors(), 1);
    expect(await storedKeys(), [keyFor(1)]);
  });

  test('every color goes when no track is left', () async {
    await db.upsertCoverColors([sampleFor(keyFor(1)), sampleFor(keyFor(2))]);
    expect(await db.deleteOrphanCoverColors(), 2);
    expect(await storedKeys(), isEmpty);
  });

  test('cover keys of one root', () async {
    await track(rootA, '1.mp3', keyFor(1));
    await track(rootA, '2.mp3', keyFor(1));
    await track(rootA, '3.mp3', null);
    await track(rootB, '4.mp3', keyFor(2));
    expect(await db.coverKeysOfRoot(rootA), {keyFor(1)});
    expect(await db.coverKeysOfRoot(rootB), {keyFor(2)});
  });
}
