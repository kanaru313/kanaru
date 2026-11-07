import 'hls_lines.dart';
import 'hls_master_parser.dart';
import 'hls_media_parser.dart';
import 'hls_models.dart';
import 'hls_refusal.dart';

export 'hls_models.dart';
export 'hls_refusal.dart';
export 'hls_variant_choice.dart';

/// Parses an HLS playlist ([bytes], UTF-8) fetched from [base] into a media
/// or a master playlist. Pure: no network, no host check. Anything that must
/// not be played throws [HlsRefusal].
///
/// A playlist with `EXT-X-STREAM-INF` is a master, one with `EXTINF` a media
/// playlist; both in one, `EXT-X-SKIP` or `EXT-X-DEFINE` → `invalid`.
HlsPlaylist parseHlsPlaylist(List<int> bytes, Uri base) {
  final lines = lexHlsPlaylist(bytes);
  var hasSegments = false;
  var hasVariants = false;
  for (final line in lines) {
    if (line is! HlsTag) continue;
    switch (line.name) {
      case 'EXT-X-SKIP' || 'EXT-X-DEFINE':
        throw const HlsRefusal(HlsRefusalKind.invalid);
      case 'EXTINF':
        hasSegments = true;
      case 'EXT-X-STREAM-INF':
        hasVariants = true;
    }
  }
  if (hasSegments && hasVariants) {
    throw const HlsRefusal(HlsRefusalKind.invalid);
  }
  return hasVariants ? parseHlsMaster(lines, base) : parseHlsMedia(lines, base);
}
