import 'hls_attribute_list.dart';
import 'hls_limits.dart';
import 'hls_lines.dart';
import 'hls_models.dart';
import 'hls_refusal.dart';
import 'hls_values.dart';

/// Builds a master playlist from [lines], resolving URIs against [base].
///
/// An `EXT-X-STREAM-INF` takes the next URI line; a second one before it, or
/// the end of the playlist, is `invalid`, as is a URI line with no
/// `EXT-X-STREAM-INF`. An `EXT-X-MEDIA` without `TYPE` or `GROUP-ID` cannot
/// be chosen and is left out. More variants or renditions than the bounds →
/// `tooLarge`.
HlsMasterPlaylist parseHlsMaster(List<HlsLine> lines, Uri base) {
  final variants = <HlsVariant>[];
  final renditions = <HlsRendition>[];
  Map<String, String>? pending;

  for (final line in lines) {
    switch (line) {
      case HlsUriLine(:final text):
        final attributes = pending;
        if (attributes == null) throw const HlsRefusal(HlsRefusalKind.invalid);
        pending = null;
        if (variants.length >= hlsMaxVariants) {
          throw const HlsRefusal(HlsRefusalKind.tooLarge);
        }
        variants.add(_variant(attributes, resolveHlsUri(base, text)));
      case HlsTag(:final name, :final value):
        if (name == 'EXT-X-STREAM-INF') {
          if (pending != null) throw const HlsRefusal(HlsRefusalKind.invalid);
          pending = parseHlsAttributeList(value);
        } else if (name == 'EXT-X-MEDIA') {
          final rendition = _rendition(parseHlsAttributeList(value), base);
          if (renditions.length >= hlsMaxRenditions) {
            throw const HlsRefusal(HlsRefusalKind.tooLarge);
          }
          if (rendition != null) renditions.add(rendition);
        }
    }
  }
  if (pending != null || variants.isEmpty) {
    throw const HlsRefusal(HlsRefusalKind.invalid);
  }
  return HlsMasterPlaylist(variants: variants, renditions: renditions);
}

HlsVariant _variant(Map<String, String> attributes, Uri uri) {
  final codecs = attributes['CODECS']
      ?.split(',')
      .map((codec) => codec.trim())
      .where((codec) => codec.isNotEmpty)
      .toList();
  final audio = attributes['AUDIO'];
  return HlsVariant(
    uri: uri,
    bandwidth: parseHlsUnsigned(attributes['BANDWIDTH']) ?? 0,
    codecs: codecs == null || codecs.isEmpty ? null : codecs,
    audioGroup: audio == null || audio.isEmpty ? null : audio,
  );
}

HlsRendition? _rendition(Map<String, String> attributes, Uri base) {
  final type = attributes['TYPE'];
  final group = attributes['GROUP-ID'];
  if (type == null || group == null) return null;
  final uri = attributes['URI'];
  return HlsRendition(
    type: type,
    groupId: group,
    uri: uri == null ? null : resolveHlsUri(base, uri),
    isDefault: attributes['DEFAULT'] == 'YES',
    isAutoselect: attributes['AUTOSELECT'] == 'YES',
  );
}
