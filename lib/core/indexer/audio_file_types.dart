/// File extensions the player and the library indexer accept, lower case.
const audioExtensions = [
  'mp3', 'flac', 'm4a', 'aac', 'alac', 'ogg', 'oga', 'opus', //
  'wav', 'aif', 'aiff', 'ape', 'wv', 'dsf', 'dff',
];

/// Whether [path] ends in one of [audioExtensions] (case-insensitive).
bool isAudioFile(String path) {
  final dot = path.lastIndexOf('.');
  return dot >= 0 &&
      audioExtensions.contains(path.substring(dot + 1).toLowerCase());
}
