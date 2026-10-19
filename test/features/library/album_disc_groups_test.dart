import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/features/library/albums/album_disc_groups.dart';

BrowseTrack track(int id, int? disc) =>
    BrowseTrack(id: id, path: '/$id', title: '$id', discNo: disc);

void main() {
  test('groups runs of the same disc, keeping the order', () {
    final groups = groupByDisc([
      track(1, 1),
      track(2, 1),
      track(3, 2),
      track(4, null),
    ]);
    expect([for (final g in groups) g.disc], [1, 2, null]);
    expect([for (final t in groups.first.tracks) t.id], [1, 2]);
  });

  test('one disc, or none known, is one group', () {
    expect(groupByDisc([track(1, null), track(2, null)]), hasLength(1));
    expect(groupByDisc([track(1, 1)]), hasLength(1));
    expect(groupByDisc(const []), isEmpty);
  });
}
