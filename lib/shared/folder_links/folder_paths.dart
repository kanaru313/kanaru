/// The last part of the directory [path] ("/music/Rock" gives "Rock").
String folderName(String path) {
  final trimmed = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  if (trimmed == '/') return '/';
  return trimmed.substring(trimmed.lastIndexOf('/') + 1);
}

/// The directory that holds [path] ("/music/Rock" gives "/music"); empty for
/// a top-level directory.
String parentPath(String path) {
  final cut = path.lastIndexOf('/');
  return cut <= 0 ? '' : path.substring(0, cut);
}
