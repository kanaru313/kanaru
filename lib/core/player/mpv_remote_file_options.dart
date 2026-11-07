import 'dart:async';

import '../sources/source_models.dart';

/// How long the load hook waits for the format of a remote track. Longer than
/// the stream proxy's own wait for it (25 s), so the proxy's null comes first.
const mpvRemoteFormatWait = Duration(seconds: 30);

/// How many proxy URLs [HandedOutUrls] remembers.
const handedOutUrlLimit = 32;

/// The mpv options a remote track of [format] needs on top of the global ones,
/// as `(name, value)`, to be set as `file-local-options/<name>` while the
/// track loads.
///
/// An HLS track is opened by libavformat's `hls` demuxer, which fetches the
/// segments (and, for AES-128, the key) from the loopback proxy as nested
/// opens; the global `protocol_whitelist=file` would refuse them. The
/// brackets of the whitelist are required: mpv's key-value list parser splits
/// the comma form at the commas and drops it. A progressive track needs none.
List<(String, String)> mpvRemoteFileOptions(RemoteStreamFormat format) =>
    switch (format) {
      RemoteStreamFormat.hls => const [
        ('demuxer-lavf-format', 'hls'),
        ('demuxer-lavf-o', 'protocol_whitelist=[http,tcp,crypto]'),
      ],
      RemoteStreamFormat.progressive => const [],
    };

/// The last [handedOutUrlLimit] proxy URLs the backend gave mpv. Only these
/// may get wider options: a `path` that was not handed out (every local file)
/// never does.
class HandedOutUrls {
  final _urls = <String>{};

  /// Remembers [url], forgetting the oldest one past the limit.
  void add(String url) {
    _urls
      ..remove(url)
      ..add(url);
    while (_urls.length > handedOutUrlLimit) {
      _urls.remove(_urls.first);
    }
  }

  /// Whether [url] is one of the remembered URLs, character for character.
  bool contains(String url) => _urls.contains(url);
}

/// The per-file options to set for the file mpv is loading from [path]: empty
/// unless [path] is a URL in [handedOut] whose format [formatOf] says needs
/// some. [formatOf] is not called for any other path.
///
/// Waits at most [wait] for [formatOf]. A null answer, an error (reported to
/// [onError], which must not log the URL) or a timeout gives no options, and
/// the track opens as it does without them. Never throws.
Future<List<(String, String)>> mpvFileOptionsFor({
  required String path,
  required HandedOutUrls handedOut,
  required Future<RemoteStreamFormat?> Function(String url) formatOf,
  Duration wait = mpvRemoteFormatWait,
  void Function(Object error)? onError,
}) async {
  if (!handedOut.contains(path)) return const [];
  try {
    final format = await formatOf(path).timeout(wait);
    return format == null ? const [] : mpvRemoteFileOptions(format);
  } on TimeoutException {
    return const [];
  } on Object catch (error) {
    onError?.call(error);
    return const [];
  }
}
