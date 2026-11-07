/// One result of a source plugin's `search.js`, already checked and capped
/// (see `readSourceSearchOutput`).
class SourceItem {
  const SourceItem({
    required this.id,
    required this.title,
    this.artist,
    this.duration,
    this.artworkUrl,
    this.webUrl,
  });

  /// The plugin's id of the item, handed back to `stream.js` as it came.
  final String id;
  final String title;
  final String? artist;

  /// Null when the plugin did not know it (it sends `0` then).
  final Duration? duration;

  /// Absolute `https` URLs, or null.
  final String? artworkUrl;
  final String? webUrl;

  @override
  bool operator ==(Object other) =>
      other is SourceItem &&
      other.id == id &&
      other.title == title &&
      other.artist == artist &&
      other.duration == duration &&
      other.artworkUrl == artworkUrl &&
      other.webUrl == webUrl;

  @override
  int get hashCode =>
      Object.hash(id, title, artist, duration, artworkUrl, webUrl);

  @override
  String toString() => 'SourceItem($id, $title)';
}

/// One page of search results. [next] asks for the page after it; null when
/// there is none. A page may be empty and still have a [next].
class SourceSearchPage {
  const SourceSearchPage({required this.items, this.next});

  final List<SourceItem> items;
  final String? next;
}

/// How the bytes behind a stream URL are laid out. The name goes into the
/// `formats` input of `stream.js`.
enum RemoteStreamFormat {
  /// One whole file, served with ranges.
  progressive,

  /// An HLS playlist (media or master) of segments.
  hls,
}

/// Where the audio of one item is, as `stream.js` resolved it. Never logged:
/// the [url] and [headers] may hold a signature or a cookie.
class SourceStream {
  const SourceStream({
    required this.url,
    required this.headers,
    required this.mimeType,
    this.format = RemoteStreamFormat.progressive,
    this.bitrate,
    this.expiresAt,
  });

  /// Absolute `https`, no explicit port, no user info.
  final Uri url;

  /// To send with every request for [url]: lower-case names, filtered like
  /// any plugin request header, never `range` or `if-range`.
  final Map<String, String> headers;

  /// `audio/…`, `video/webm` or `video/mp4`, or an HLS playlist type,
  /// parameters allowed.
  final String mimeType;

  /// [RemoteStreamFormat.hls] when [mimeType] is an HLS playlist type: [url]
  /// is then a playlist, not a file.
  final RemoteStreamFormat format;

  /// Bits per second; null when unknown.
  final int? bitrate;

  /// When [url] stops working; null when unknown.
  final DateTime? expiresAt;
}

/// Why a source plugin call gave nothing. The UI words it by [kind].
enum SourceFailureKind {
  /// The user has not accepted this plugin's notice (or withdrew it): nothing
  /// was sent.
  notConsented,

  /// A required setting of the plugin is empty: the script did not run.
  needsConfig,

  /// Nothing to report: the plugin is missing, removed, being updated, not a
  /// source plugin, or the caller abandoned the call. Callers drop it.
  skipped,

  /// The service refused the credentials.
  auth,

  /// The service asks to wait (`rateLimited` or `quota`).
  rateLimited,

  /// The service failed or answered something the plugin could not read.
  unavailable,

  /// A request failed or timed out, or loading the plugin took too long.
  network,

  /// The script's output breaks the documented shape.
  invalidOutput,

  /// Every plugin worker was busy; nothing ran.
  busy,

  /// The app failed (the runtime, or the plugin's files or settings could not
  /// be read).
  internal,
}

/// A failed source plugin call. [message] is the text the script passed to
/// `Response.error`, else empty; it goes to the log, and the Online screen
/// shows it under a failed search.
class SourceFailure implements Exception {
  const SourceFailure({required this.kind, this.message = ''});

  final SourceFailureKind kind;
  final String message;

  @override
  String toString() => 'SourceFailure(${kind.name})';
}
