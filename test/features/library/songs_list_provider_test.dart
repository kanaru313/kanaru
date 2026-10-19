import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/settings/library_sort.dart';
import 'package:kanaru/features/library/songs/songs_list_provider.dart';

void main() {
  test('every Songs sort field maps to its database order', () {
    const table = {
      SongSortField.title: SongOrder.title,
      SongSortField.artist: SongOrder.artist,
      SongSortField.album: SongOrder.album,
      SongSortField.year: SongOrder.year,
      SongSortField.dateAdded: SongOrder.dateAdded,
      SongSortField.duration: SongOrder.duration,
    };
    expect(table.keys, SongSortField.values);
    for (final MapEntry(:key, :value) in table.entries) {
      expect(songOrderFor(key), value, reason: key.name);
    }
  });
}
