import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_request.dart';

Matcher _rejected(String reason) => throwsA(
  isA<LyricsRequestRejected>().having((e) => e.reason, 'reason', reason),
);

void main() {
  group('lyricsRequestHeaders', () {
    test('names are lower-cased and accept defaults to */*', () {
      expect(lyricsRequestHeaders({'X-Token': 'a', 'Referer': 'https://x/'}), {
        'x-token': 'a',
        'referer': 'https://x/',
        'accept': '*/*',
      });
    });

    test('a given accept (any value) is kept', () {
      expect(lyricsRequestHeaders({'Accept': 'text/html'}), {
        'accept': 'text/html',
      });
    });

    test('every denied name is dropped in any case', () {
      const denied = [
        'user-agent',
        'host',
        'connection',
        'content-length',
        'transfer-encoding',
        'te',
        'upgrade',
        'keep-alive',
        'proxy-authorization',
        'proxy-connection',
        'trailer',
        'expect',
      ];
      for (final name in denied) {
        expect(lyricsRequestHeaders({name.toUpperCase(): 'x', 'x-ok': '1'}), {
          'x-ok': '1',
          'accept': '*/*',
        }, reason: name);
      }
    });

    test(
      'a value with CR, LF, NUL, DEL or a non-ASCII character is rejected',
      () {
        for (final value in [
          'a\r\nX: b',
          'a\nb',
          'a\rb',
          'a\u0000b',
          'a\u007fb',
          'caf\u00e9',
          'caf\u0153\u4e2d',
        ]) {
          expect(
            () => lyricsRequestHeaders({'x-a': value}),
            _rejected('header value'),
            reason: value.codeUnits.toString(),
          );
        }
      },
    );

    test('tab is allowed in a value', () {
      expect(lyricsRequestHeaders({'x-a': 'a\tb c'})['x-a'], 'a\tb c');
    });

    test('names that differ only in case keep the last value', () {
      expect(lyricsRequestHeaders({'X-A': '1', 'x-a': '2'})['x-a'], '2');
    });

    test('a name that is not a token is rejected, even a denied one', () {
      for (final name in ['', 'a b', 'a:b', 'a\nb', 'hé', 'user agent']) {
        expect(
          () => lyricsRequestHeaders({name: 'x'}),
          _rejected('header name'),
          reason: name,
        );
      }
    });
  });

  group('checkLyricsRequest', () {
    final uri = Uri.parse('https://a.example/');

    test('GET and POST pass, upper or lower case', () {
      expect(
        checkLyricsRequest(LyricsHttpRequest(method: 'get', uri: uri)),
        'GET',
      );
      expect(
        checkLyricsRequest(
          LyricsHttpRequest(method: 'post', uri: uri, body: [1]),
        ),
        'POST',
      );
    });

    test('other methods are rejected', () {
      for (final method in [
        'PUT',
        'DELETE',
        'HEAD',
        '',
        'GET ',
        'Get',
        'pOST',
      ]) {
        expect(
          () => checkLyricsRequest(LyricsHttpRequest(method: method, uri: uri)),
          _rejected('method'),
          reason: method,
        );
      }
    });

    test('a body byte outside 0..255 is rejected', () {
      for (final bad in [-1, 256, 0x4e2d]) {
        expect(
          () => checkLyricsRequest(
            LyricsHttpRequest(method: 'POST', uri: uri, body: [1, bad]),
          ),
          _rejected('body'),
          reason: '$bad',
        );
      }
    });

    test('a body goes only with POST and is at most 256 KiB', () {
      expect(
        () => checkLyricsRequest(
          LyricsHttpRequest(method: 'GET', uri: uri, body: [1]),
        ),
        _rejected('body with GET'),
      );
      expect(
        checkLyricsRequest(
          LyricsHttpRequest(
            method: 'POST',
            uri: uri,
            body: List.filled(lyricsMaxRequestBytes, 0),
          ),
        ),
        'POST',
      );
      expect(
        () => checkLyricsRequest(
          LyricsHttpRequest(
            method: 'POST',
            uri: uri,
            body: List.filled(lyricsMaxRequestBytes + 1, 0),
          ),
        ),
        _rejected('body too large'),
      );
    });
  });
}
