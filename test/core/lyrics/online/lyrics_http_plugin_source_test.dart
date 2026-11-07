import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_retry.dart'
    show LyricsRequestAbandoned;

import 'counting_http_client.dart';

LyricsHttpRequest _get(String url) =>
    LyricsHttpRequest(method: 'GET', uri: Uri.parse(url));

const _hosts = ['*.googlevideo.com', 'www.youtube.com'];
const _url = 'https://www.youtube.com/youtubei/v1/search';

Future<Object?> _error(Future<Object?> call) async {
  try {
    await call;
  } on Object catch (e) {
    return e;
  }
  return null;
}

Matcher _kind(LyricsFetchKind kind) =>
    isA<LyricsFetchException>().having((e) => e.kind, 'kind', kind);

void main() {
  late CountingHttpClient client;

  setUp(() => client = CountingHttpClient());

  LyricsHttp http({bool Function()? allowed, bool Function()? abandoned}) =>
      LyricsHttp.forPluginSource(
        _hosts,
        client,
        allowed: allowed,
        abandoned: abandoned,
      );

  test('without consent nothing reaches the client', () async {
    expect(
      await _error(http(allowed: () => false).send(_get(_url))),
      _kind(LyricsFetchKind.notConsented),
    );
    expect(
      await _error(http(allowed: () => false).get(Uri.parse(_url))),
      _kind(LyricsFetchKind.notConsented),
    );
    expect(client.opened, 0);
  });

  test('consent is asked before every send', () async {
    var allowed = true;
    final source = http(allowed: () => allowed);

    // The counting client fails every connection: the send went out.
    expect(
      await _error(source.send(_get(_url))),
      _kind(LyricsFetchKind.network),
    );
    allowed = false;
    expect(
      await _error(source.send(_get(_url))),
      _kind(LyricsFetchKind.notConsented),
    );
    expect(client.opened, 1);
  });

  test('once abandoned no further send starts', () async {
    var gone = false;
    final source = http(allowed: () => true, abandoned: () => gone);

    await _error(source.send(_get(_url)));
    gone = true;
    expect(
      await _error(source.send(_get(_url))),
      isA<LyricsRequestAbandoned>(),
    );
    expect(client.opened, 1);
  });

  test('abandoned is asked before consent', () async {
    expect(
      await _error(
        http(allowed: () => false, abandoned: () => true).send(_get(_url)),
      ),
      isA<LyricsRequestAbandoned>(),
    );
    expect(client.opened, 0);
  });

  test('a host one label under a wildcard of the plugin is allowed', () async {
    final error = await _error(
      http().send(_get('https://rr1---sn-x.googlevideo.com/videoplayback')),
    );
    expect(error, isNot(_kind(LyricsFetchKind.blockedHost)));
    expect(client.opened, 1);
  });

  test('strict rules: http, a port, user info or another host are '
      'blocked', () async {
    for (final url in [
      'http://www.youtube.com/x',
      'https://www.youtube.com:8443/x',
      'https://user@www.youtube.com/x',
      'https://googlevideo.com/x',
      'https://a.b.googlevideo.com/x',
      'https://example.com/x',
    ]) {
      expect(
        await _error(http().send(_get(url))),
        _kind(LyricsFetchKind.blockedHost),
        reason: url,
      );
    }
    expect(client.opened, 0);
  });
}
