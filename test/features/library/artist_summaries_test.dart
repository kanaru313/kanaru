import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/features/library/artists/artist_summaries.dart';

/// Keys as SQL's lower() makes them: ASCII only.
String _asciiLower(String s) =>
    s.replaceAllMapped(RegExp('[A-Z]'), (m) => m[0]!.toLowerCase());

ArtistCredit credit(
  String artist,
  int tracks, [
  List<AlbumKey> albums = const [],
]) => ArtistCredit(
  artist: artist,
  artistKey: _asciiLower(artist),
  trackCount: tracks,
  albumKeys: albums.toSet(),
);

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

  test('ASCII case merges; the first spelling is shown', () {
    final all = build([credit('ANN', 1), credit('Ann', 1), credit('Ánn', 1)]);
    expect(all['ann']!.name, 'ANN');
    expect(all['ann']!.songCount, 2);
    expect(all['Ánn']!.songCount, 1);
  });

  test('empty parts are dropped', () {
    expect(build([credit('; ', 1)]), isEmpty);
    expect(build([credit('Ann; ', 1)]).keys, ['ann']);
  });
}
