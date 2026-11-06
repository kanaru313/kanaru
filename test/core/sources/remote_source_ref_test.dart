import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/remote_source_ref.dart';

const _id = 'plugin-abc123def456';

void main() {
  test('round-trips item ids with "/", "%" and non-ASCII characters', () {
    for (final itemId in [
      'dQw4w9WgXcQ',
      'a/b/c',
      '100%',
      '%2F',
      'Nhạc Việt 🎵',
      'x?y#z&w=1',
      ' ',
    ]) {
      final ref = RemoteSourceRef(installId: _id, itemId: itemId);
      final uri = remoteTrackUri(ref);
      expect(uri, startsWith('kanaru-source:$_id/'));
      expect(uri.substring('kanaru-source:$_id/'.length), isNot(contains('/')));
      expect(parseRemoteTrackUri(uri), ref, reason: itemId);
      expect(isRemoteTrackUri(uri), isTrue);
    }
  });

  test('the uri carries no artwork or web URL', () {
    const ref = RemoteSourceRef(
      installId: _id,
      itemId: 'x',
      artworkUrl: 'https://img.example.com/a.jpg',
      webUrl: 'https://example.com/x',
    );
    final back = parseRemoteTrackUri(remoteTrackUri(ref))!;
    expect(back.itemId, 'x');
    expect(back.artworkUrl, isNull);
    expect(back.webUrl, isNull);
  });

  test('refuses what is not a remote track uri', () {
    for (final uri in [
      '/music/song.flac',
      'file:///music/song.flac',
      'kanaru-source:',
      'kanaru-source:$_id',
      'kanaru-source:$_id/',
      'kanaru-source:plugin-ABC123DEF456/x',
      'kanaru-source:plugin-abc/x',
      'kanaru-source:../etc/x',
      'kanaru-source:$_id/a/b',
      'kanaru-source:$_id/%zz',
      'kanaru-source:$_id/%41',
    ]) {
      expect(parseRemoteTrackUri(uri), isNull, reason: uri);
      expect(isRemoteTrackUri(uri), isFalse, reason: uri);
    }
  });

  test('equal by every field', () {
    const a = RemoteSourceRef(installId: _id, itemId: 'x');
    expect(a, const RemoteSourceRef(installId: _id, itemId: 'x'));
    expect(
      a.hashCode,
      const RemoteSourceRef(installId: _id, itemId: 'x').hashCode,
    );
    expect(a == const RemoteSourceRef(installId: _id, itemId: 'y'), isFalse);
  });
}
