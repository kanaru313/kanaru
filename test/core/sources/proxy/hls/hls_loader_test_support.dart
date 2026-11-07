import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/hls/hls_refusal.dart';
import 'package:kanaru/core/sources/proxy/hls/hls_playlist_loader.dart';
import 'package:kanaru/core/sources/proxy/hls/hls_resolve_failure.dart';
import 'package:kanaru/core/sources/proxy/stream_resolver.dart';
import 'package:kanaru/core/sources/source_models.dart';

import '../proxy_test_support.dart';

/// The hosts the tests declare; the fake upstream is `127.0.0.1`.
const declaredHosts = {'127.0.0.1', 'cdn2.example.com'};

bool declaredHost(Uri url) =>
    (url.scheme == 'http' || url.scheme == 'https') &&
    declaredHosts.contains(url.host);

/// A fake upstream with a loader over a real client, and the HLS stream the
/// tests resolve to.
class LoaderRig {
  LoaderRig._(this.upstream, this.client, this.loader);

  static Future<LoaderRig> start({
    Duration bodyTimeout = const Duration(seconds: 15),
  }) async {
    final upstream = await FakeUpstream.start(const []);
    final client = HttpClient();
    return LoaderRig._(
      upstream,
      client,
      HlsPlaylistLoader(client, bodyTimeout: bodyTimeout),
    );
  }

  final FakeUpstream upstream;
  final HttpClient client;
  final HlsPlaylistLoader loader;

  /// The consent the streams ask.
  bool allowed = true;

  Future<void> close() async {
    client.close(force: true);
    await upstream.close();
  }

  /// Makes [path] answer [text] as a playlist.
  void serve(String path, String text) {
    upstream.bodies[path] = utf8.encode(text);
    upstream.contentTypes[path] = 'application/vnd.apple.mpegurl';
  }

  /// An HLS stream whose playlist is at [path].
  ResolvedStream stream([String path = '/pl.m3u8']) => ResolvedStream(
    url: upstream.url(path),
    headers: const {'x-plugin': 'yes'},
    format: RemoteStreamFormat.hls,
    allowed: () => allowed,
    redirectAllowed: declaredHost,
  );

  Future<ResolvedStream> load([
    String path = '/pl.m3u8',
    bool Function()? abandoned,
  ]) async {
    final stream = this.stream(path);
    return stream.withHls(
      await loader.load('k', stream, abandoned: abandoned ?? () => false),
    );
  }

  /// The paths the upstream saw, in order.
  List<String> get paths => [for (final r in upstream.requests) r.path];
}

/// A media playlist of [count] segments of 4 s named `seg<i>.ts`, with
/// [extra] tag lines before the first one.
String segments(int count, {List<String> extra = const []}) => [
  '#EXTM3U',
  '#EXT-X-TARGETDURATION:4',
  ...extra,
  for (var i = 0; i < count; i++) ...['#EXTINF:4.0,', 'seg$i.ts'],
  '#EXT-X-ENDLIST',
].join('\n');

/// Matches an `HlsResolveFailure` of [kind].
Matcher refusedWith(HlsRefusalKind kind) =>
    throwsA(isA<HlsResolveFailure>().having((e) => e.kind, 'kind', kind));
