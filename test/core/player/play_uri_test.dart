import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/play_uri.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/sources/remote_source_ref.dart';

void main() {
  const ref = RemoteSourceRef(installId: 'plugin-abcdefghijkl', itemId: 'vid1');
  final remote = Track(uri: remoteTrackUri(ref), title: 'Remote', remote: ref);
  const local = Track(uri: '/music/a.flac', title: 'Local');

  group('playUriFor', () {
    test('a remote track plays the URL the proxy gives', () async {
      final asked = <RemoteSourceRef>[];
      final errors = <Object>[];

      final uri = await playUriFor(remote, (r) async {
        asked.add(r);
        return 'http://127.0.0.1:1/token/source-plugin/x';
      }, errors.add);

      expect(uri, 'http://127.0.0.1:1/token/source-plugin/x');
      expect(asked, [ref]);
      expect(errors, isEmpty);
    });

    test(
      'a failing remote URL falls back to the uri and reports once',
      () async {
        final errors = <Object>[];
        final failure = StateError('proxy down');

        final uri = await playUriFor(
          remote,
          (_) async => throw failure,
          errors.add,
        );

        expect(uri, remote.uri);
        expect(errors, [failure]);
      },
    );

    test('a remote track without a URL source plays its uri', () async {
      final errors = <Object>[];

      final uri = await playUriFor(remote, null, errors.add);

      expect(uri, remote.uri);
      expect(errors, isEmpty);
    });

    test('a local track plays its uri and never asks for a URL', () async {
      var calls = 0;
      final errors = <Object>[];

      final uri = await playUriFor(local, (_) async {
        calls++;
        return 'http://unused';
      }, errors.add);

      expect(uri, '/music/a.flac');
      expect(calls, 0);
      expect(errors, isEmpty);
    });
  });
}
