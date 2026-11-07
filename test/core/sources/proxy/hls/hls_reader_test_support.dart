import 'dart:async';

import 'package:kanaru/core/sources/proxy/hls/hls_playlist_loader.dart';
import 'package:kanaru/core/sources/proxy/hls/hls_proxy_names.dart';
import 'package:kanaru/core/sources/proxy/hls/hls_resource_reader.dart';
import 'package:kanaru/core/sources/proxy/proxy_body.dart';
import 'package:kanaru/core/sources/proxy/range_request.dart';
import 'package:kanaru/core/sources/proxy/resolved_streams.dart';
import 'package:kanaru/core/sources/proxy/stream_resolver.dart';
import 'package:kanaru/core/sources/source_models.dart';

import '../proxy_test_support.dart';
import 'hls_loader_test_support.dart';

/// A reader over a fake upstream, with a `stream.js` stand-in: the n-th run
/// (from 1) answers an HLS stream whose playlist is at `/p<n>.m3u8`.
class ReaderRig {
  ReaderRig._(this.loader, this.reader, this.streams, this.runs);

  static Future<ReaderRig> start({
    int segmentLimit = hlsMaxSegmentBytes,
    int initLimit = hlsMaxInitBytes,
    Duration stallTimeout = const Duration(seconds: 15),
    DateTime Function()? clock,
    DateTime? Function()? expiresAt,
    RemoteStreamFormat format = RemoteStreamFormat.hls,
  }) async {
    final loader = await LoaderRig.start();
    final runs = <bool>[];
    late final ResolvedStreams streams;
    Future<ResolvedStream> resolve(
      String key, {
      required bool fresh,
      required bool Function() abandoned,
    }) async {
      runs.add(fresh);
      final stream = loader.stream('/p${runs.length}.m3u8');
      return ResolvedStream(
        url: stream.url,
        headers: stream.headers,
        format: format,
        expiresAt: expiresAt?.call(),
        allowed: stream.allowed,
        redirectAllowed: stream.redirectAllowed,
      );
    }

    streams = ResolvedStreams(
      hlsAwareResolve(resolve, loader.loader),
      clock: clock,
    );
    final reader = HlsResourceReader(
      loader.client,
      loader.loader.memory,
      segmentLimit: segmentLimit,
      initLimit: initLimit,
      stallTimeout: stallTimeout,
    );
    return ReaderRig._(loader, reader, streams, runs);
  }

  final LoaderRig loader;
  final HlsResourceReader reader;
  final ResolvedStreams streams;

  /// The `fresh` flag of each `stream.js` run.
  final List<bool> runs;

  FakeUpstream get upstream => loader.upstream;

  /// The consent the streams ask.
  set allowed(bool value) => loader.allowed = value;

  Future<void> close() => loader.close();

  /// The playthrough of item `k` (begun once, then reused).
  Playthrough get playthrough =>
      streams.lookup('k') ?? streams.begin('k', testInstallId);

  /// Answers [path] with [bytes] as a media file.
  void serveBytes(String path, List<int> bytes) =>
      upstream.bodies[path] = bytes;

  /// Opens sub-resource [name] (`hls/<rev>/s0.ts` ...) with [range].
  Future<ProxyAnswer> open(String name, [String? range]) => reader.open(
    playthrough,
    parseHlsResourceName(name)!,
    RangeRequest.parse(range),
  );

  /// The paths the upstream saw, in order.
  List<String> get paths => loader.paths;
}

/// What an answer's body held, read to its end.
Future<List<int>> bodyOf(ProxyAnswer answer) async {
  final out = <int>[];
  await answer.body?.forEach(out.addAll);
  return out;
}
