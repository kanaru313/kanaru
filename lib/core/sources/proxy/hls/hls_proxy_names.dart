/// What a proxy sub-resource of an HLS item is.
enum HlsResourceKind { segment, init, key }

/// A parsed sub-resource name: `hls/<rev>/s<i>.<ext>`, `hls/<rev>/i<j>.mp4`
/// or `hls/<rev>/k<j>.key`, as they follow the item's proxy URL.
class HlsResource {
  const HlsResource({
    required this.kind,
    required this.rev,
    required this.index,
    this.ext,
  });

  final HlsResourceKind kind;
  final int rev;

  /// i for a segment, j for an init section or a key.
  final int index;

  /// The segment's ext; null for an init section (`mp4`) and a key (`key`).
  final String? ext;

  /// The `content-type` the proxy answers this resource with.
  String get contentType => switch (kind) {
    HlsResourceKind.segment => _segmentContentTypes[ext]!,
    HlsResourceKind.init => 'audio/mp4',
    HlsResourceKind.key => 'application/octet-stream',
  };
}

const _segmentContentTypes = {
  'ts': 'video/mp2t',
  'aac': 'audio/aac',
  'mp3': 'audio/mpeg',
  'm4s': 'audio/mp4',
  'ac3': 'audio/ac3',
  'ec3': 'audio/eac3',
};

const _extByUriExt = {
  'ts': 'ts',
  'm2ts': 'ts',
  'mts': 'ts',
  'mpegts': 'ts',
  'mpg': 'ts',
  'aac': 'aac',
  'adts': 'aac',
  'mp3': 'mp3',
  'm4s': 'm4s',
  'mp4': 'm4s',
  'm4a': 'm4s',
  'm4v': 'm4s',
  'cmfa': 'm4s',
  'cmfv': 'm4s',
  'ac3': 'ac3',
  'ec3': 'ec3',
  'eac3': 'ec3',
};

/// The ext of the proxy name of a segment fetched from [uri]: from the
/// lower-cased extension of its path, else `m4s` when the segment has an init
/// section ([hasInit]) and `ts` when it has not. The ext only describes the
/// segment; mpv plays it whatever the ext says.
String hlsSegmentExt(Uri uri, {required bool hasInit}) {
  final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  final dot = name.lastIndexOf('.');
  final fromName = dot < 0
      ? null
      : _extByUriExt[name.substring(dot + 1).toLowerCase()];
  return fromName ?? (hasInit ? 'm4s' : 'ts');
}

/// The name of segment [index] of snapshot [rev], relative to the item's
/// proxy URL.
String hlsSegmentName(int rev, int index, String ext) =>
    'hls/$rev/s$index.$ext';

/// The name of init section [index] of snapshot [rev].
String hlsInitName(int rev, int index) => 'hls/$rev/i$index.mp4';

/// The name of key [index] of snapshot [rev].
String hlsKeyName(int rev, int index) => 'hls/$rev/k$index.key';

final _name = RegExp(r'^hls/(\d{1,15})/([sik])(\d{1,9})\.([a-z0-9]+)$');

/// Parses a name relative to the item's proxy URL (`hls/…`, no leading
/// slash, no query). Null for any other shape: a number with a leading zero,
/// too many digits, `rev` 0, an ext the kind does not allow.
HlsResource? parseHlsResourceName(String name) {
  final match = _name.firstMatch(name);
  if (match == null) return null;
  final revText = match.group(1)!;
  final indexText = match.group(3)!;
  if (_leadingZero(revText) || _leadingZero(indexText)) return null;
  final rev = int.parse(revText);
  if (rev < 1) return null;
  final index = int.parse(indexText);
  final ext = match.group(4)!;
  switch (match.group(2)) {
    case 's':
      if (!_segmentContentTypes.containsKey(ext)) return null;
      return HlsResource(
        kind: HlsResourceKind.segment,
        rev: rev,
        index: index,
        ext: ext,
      );
    case 'i':
      if (ext != 'mp4') return null;
      return HlsResource(kind: HlsResourceKind.init, rev: rev, index: index);
    default:
      if (ext != 'key') return null;
      return HlsResource(kind: HlsResourceKind.key, rev: rev, index: index);
  }
}

bool _leadingZero(String digits) => digits.length > 1 && digits.startsWith('0');
