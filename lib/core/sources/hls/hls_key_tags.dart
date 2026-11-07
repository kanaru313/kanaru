import 'hls_attribute_list.dart';
import 'hls_models.dart';
import 'hls_refusal.dart';
import 'hls_values.dart';

/// Reads the value of an `EXT-X-KEY` tag. Returns the key to use from the
/// next segment on, or null for `METHOD=NONE` (not encrypted).
///
/// Only `AES-128` with the identity key format is played: the proxy hands the
/// key to the decrypting side, it never holds a cipher. Any other `METHOD`
/// (`SAMPLE-AES`, `SAMPLE-AES-CTR`, unknown) or a `KEYFORMAT` other than
/// `identity` → `protected`. A missing `METHOD`, an `AES-128` key without
/// `URI` or with a bad `IV` → `invalid`.
HlsKey? parseHlsKey(String? value, Uri base) {
  final attributes = parseHlsAttributeList(value);
  final method = attributes['METHOD'];
  if (method == null) throw const HlsRefusal(HlsRefusalKind.invalid);
  if (method == 'NONE') return null;
  if (method != 'AES-128') throw const HlsRefusal(HlsRefusalKind.protected);
  final format = attributes['KEYFORMAT'];
  if (format != null && format != 'identity') {
    throw const HlsRefusal(HlsRefusalKind.protected);
  }
  final iv = attributes['IV'];
  final parsedIv = iv == null ? null : parseHlsIv(iv);
  if (iv != null && parsedIv == null) {
    throw const HlsRefusal(HlsRefusalKind.invalid);
  }
  return HlsKey(uri: resolveHlsUri(base, attributes['URI']), iv: parsedIv);
}

/// Reads the value of an `EXT-X-MAP` tag: `URI`, and optionally `BYTERANGE`
/// (`"length@offset"`, the offset required here). [key] is the key in force
/// at the tag's line (null: none); the init section is read under it.
HlsInitSection parseHlsMap(String? value, Uri base, HlsKey? key) {
  final attributes = parseHlsAttributeList(value);
  final uri = resolveHlsUri(base, attributes['URI']);
  final range = attributes['BYTERANGE'];
  return HlsInitSection(
    uri: uri,
    byteRange: range == null ? null : _initRange(range),
    key: key,
  );
}

HlsByteRange _initRange(String text) {
  final parsed = parseHlsByteRangeText(text);
  if (parsed == null) throw const HlsRefusal(HlsRefusalKind.invalid);
  return completeHlsByteRange(parsed, null);
}
