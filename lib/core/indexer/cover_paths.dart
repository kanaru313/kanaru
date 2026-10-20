/// Names inside the cover thumbnail folder, shared by the cache cleanup and
/// the views that show covers.
///
/// A key is `<ab>/<hash>.jpg`: `hash` is the 64-character hex blake3 of the
/// original image bytes and `ab` its first two characters, so the folder
/// never holds tens of thousands of files side by side.
library;

/// A shard folder name: two lowercase hex characters.
final coverShardPattern = RegExp(r'^[0-9a-f]{2}$');

/// A thumbnail file name inside a shard.
final coverFilePattern = RegExp(r'^[0-9a-f]{64}\.jpg$');

/// Prefix of the temp files the tag reader writes before renaming them into
/// place. Leftovers come from a crash and are safe to delete.
const coverTempPrefix = '.kanaru-tmp';

/// Whether [key] has the shape of a cover key, so joining it to the cover
/// folder can never point outside it.
bool isCoverKey(String key) {
  final slash = key.indexOf('/');
  if (slash != 2) return false;
  final shard = key.substring(0, 2);
  final file = key.substring(3);
  return coverShardPattern.hasMatch(shard) &&
      coverFilePattern.hasMatch(file) &&
      file.startsWith(shard);
}

/// The thumbnail file of [key] in [directory]; `null` when either is missing
/// or the key is malformed.
String? coverPath(String? directory, String? key) {
  if (directory == null || key == null || !isCoverKey(key)) return null;
  return '$directory/$key';
}
