import 'dart:math';

import '../../../database/library_database.dart';
import '../../../database/lyrics_plugin_queries.dart';

const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
const _idLength = 12;

/// Shape of every plugin id: `plugin-` and 12 characters of `[a-z0-9]`.
final pluginInstallIdPattern = RegExp('^$lyricsPluginIdPrefix[a-z0-9]{12}\$');

/// A random plugin id (about 62 bits). Uses [Random.secure] unless a test
/// passes its own generator.
String newPluginInstallId([Random? random]) {
  final rng = random ?? Random.secure();
  final chars = [
    for (var i = 0; i < _idLength; i++)
      _alphabet[rng.nextInt(_alphabet.length)],
  ];
  return '$lyricsPluginIdPrefix${chars.join()}';
}

/// A new id no record (removed ones included) uses yet.
Future<String> uniquePluginInstallId(
  LibraryDatabase db, [
  Random? random,
]) async {
  for (var attempt = 0; attempt < 8; attempt++) {
    final id = newPluginInstallId(random);
    if (await db.lyricsPluginById(id) == null) return id;
  }
  throw StateError('Could not find a free plugin id');
}
