/// Local file path of a track uri, or `null`. A plain absolute path is
/// returned as is; a `file://` uri without a host is decoded. Anything else,
/// malformed uris included, gives `null`. Never throws. No symlink
/// normalization: a path spelled differently from the library row is not
/// found, and its art falls back like a non-library track's.
String? localPathOf(String uri) {
  if (uri.startsWith('/')) return uri;
  final parsed = Uri.tryParse(uri);
  if (parsed == null || parsed.scheme != 'file' || parsed.host.isNotEmpty) {
    return null;
  }
  try {
    return parsed.toFilePath();
  } on Object {
    // An encoded slash (`%2F`) and the like have no file path.
    return null;
  }
}
