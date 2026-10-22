import 'package:drift/drift.dart';

import '../cover_colors/cover_color_extractor.dart';
import '../cover_colors/cover_palette.dart';
import 'library_database.dart';

/// Reads and writes of the `cover_colors` table (see `CoverColors` in
/// `library_tables.dart` for the stored format). Nothing watches the table.
extension CoverColorQueries on LibraryDatabase {
  /// The stored colors of cover [key], or `null` when there is no row, the
  /// row comes from another [coverColorAlgoVersion], or it is damaged.
  Future<CoverPalette?> coverPaletteOf(String key) async {
    final row =
        await (select(coverColors)..where(
              (c) =>
                  c.coverKey.equals(key) &
                  c.algoVersion.equals(coverColorAlgoVersion),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return paletteFromRow(seed: row.seed, palette: row.palette);
  }

  /// Stores the colors of every sample that is `ok` (others are ignored),
  /// with the current [coverColorAlgoVersion], replacing older rows. One
  /// transaction.
  Future<void> upsertCoverColors(List<CoverColorSample> samples) {
    final rows = [
      for (final sample in samples)
        if (sample.ok && sample.palette.isNotEmpty)
          CoverColorsCompanion.insert(
            coverKey: sample.key,
            seed: sample.seed & 0xFFFFFFFF,
            palette: encodePalette(
              sample.palette.take(maxPaletteColors).toList(),
            ),
            algoVersion: coverColorAlgoVersion,
          ),
    ];
    if (rows.isEmpty) return Future.value();
    return transaction(
      () => batch((b) => b.insertAllOnConflictUpdate(coverColors, rows)),
    );
  }

  /// The distinct cover keys of the tracks under [rootIds] whose colors are
  /// missing: no row under the current [coverColorAlgoVersion], or a damaged
  /// one (see [paletteFromRow]). In key order.
  Future<List<String>> coverKeysNeedingColors(List<int> rootIds) async {
    final keys = <String>{};
    for (var i = 0; i < rootIds.length; i += deleteChunkSize) {
      final chunk = rootIds.sublist(
        i,
        i + deleteChunkSize < rootIds.length
            ? i + deleteChunkSize
            : rootIds.length,
      );
      final marks = List.filled(chunk.length, '?').join(', ');
      final rows = await customSelect(
        'SELECT DISTINCT t.cover_key AS cover_key, c.seed AS seed, '
        'c.palette AS palette FROM tracks t '
        'LEFT JOIN cover_colors c '
        'ON c.cover_key = t.cover_key AND c.algo_version = ? '
        'WHERE t.cover_key IS NOT NULL AND t.root_id IN ($marks)',
        variables: [
          Variable.withInt(coverColorAlgoVersion),
          for (final id in chunk) Variable.withInt(id),
        ],
        readsFrom: {tracks, coverColors},
      ).get();
      for (final row in rows) {
        final seed = row.readNullable<int>('seed');
        final palette = row.readNullable<String>('palette');
        if (seed == null ||
            palette == null ||
            paletteFromRow(seed: seed, palette: palette) == null) {
          keys.add(row.read<String>('cover_key'));
        }
      }
    }
    return keys.toList()..sort();
  }

  /// Deletes the colors of covers no track points at; returns how many rows
  /// went. The only statement that deletes colors.
  ///
  /// `IS NOT NULL` is required: `tracks.cover_key` is nullable, and one NULL
  /// in the subquery makes `NOT IN` NULL for every row, so nothing would go.
  Future<int> deleteOrphanCoverColors() => customUpdate(
    'DELETE FROM cover_colors WHERE cover_key NOT IN '
    '(SELECT cover_key FROM tracks WHERE cover_key IS NOT NULL)',
    updates: {coverColors},
    updateKind: UpdateKind.delete,
  );

  /// The cover keys of the tracks of root [rootId].
  Future<Set<String>> coverKeysOfRoot(int rootId) async {
    final query = selectOnly(tracks, distinct: true)
      ..addColumns([tracks.coverKey])
      ..where(tracks.rootId.equals(rootId) & tracks.coverKey.isNotNull());
    return {for (final row in await query.get()) row.read(tracks.coverKey)!};
  }
}
