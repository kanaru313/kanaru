import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/features/library/artists/artist_summaries.dart';

ArtistCredit credit(
  String artist,
  int tracks, [
  List<AlbumKey> albums = const [],
]) =>
    ArtistCredit(artist: artist, trackCount: tracks, albumKeys: albums.toSet());

void main() {
  Map<String, ArtistSummary> build(List<ArtistCredit> credits) => {
    for (final a in buildArtistSummaries(credits)) a.key: a,
  };

  test('guests are artists; album-artist-only names are not', () {
    // "Various Artists" would only be in album_artist, which never reaches
    // the credits: there is simply no credit for it.
    final all = build([
      credit('Ann; Guest', 2, [const AlbumKey('ann', 'x')]),
      credit('Ann', 3, [
        const AlbumKey('ann', 'x'),
        const AlbumKey('ann', 'y'),
      ]),
    ]);
    expect(all.keys, {'ann', 'guest'});
    expect(all['ann']!.songCount, 5);
    expect(all['ann']!.albumCount, 2);
    expect(all['guest']!.songCount, 2);
    expect(all['guest']!.albumCount, 1);
  });

  test('a name repeated in one value counts its tracks once', () {
    final all = build([credit('Ann; Ann', 4)]);
    expect(all['ann']!.songCount, 4);
  });

  test('case merges, Unicode too; the first spelling is shown', () {
    final all = build([credit('ANN', 1), credit('Ann', 1), credit('ĐEN', 1)]);
    expect(all['ann']!.name, 'ANN');
    final reversed = build([credit('Ann', 1), credit('ANN', 1)]);
    expect(reversed['ann']!.name, 'ANN', reason: 'same name in any order');
    expect(all['ann']!.songCount, 2);
    expect(build([credit('ĐEN', 1), credit('Đen', 2)])['đen']!.songCount, 3);
  });

  test('splits on every separator the tags use', () {
    final all = build([
      credit('Ban nhạc Hương Mùa Hè;SUNI Hạ Linh', 1),
      credit('Chau Khai Phong feat. Trịnh Đình Quang', 2),
    ]);
    expect(all.keys, {
      'ban nhạc hương mùa hè',
      'suni hạ linh',
      'chau khai phong',
      'trịnh đình quang',
    });
    expect(all['suni hạ linh']!.name, 'SUNI Hạ Linh');
  });

  test('empty parts are dropped', () {
    expect(build([credit('; ', 1)]), isEmpty);
    expect(build([credit('Ann; ', 1)]).keys, ['ann']);
  });
}
