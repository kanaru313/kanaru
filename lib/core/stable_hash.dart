import 'dart:convert';

/// 32-bit FNV-1a of the UTF-8 bytes of [text]. Unlike `hashCode` it is the
/// same on every run, so placeholder colors do not change between launches.
int fnv1a(String text) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(text)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash;
}
