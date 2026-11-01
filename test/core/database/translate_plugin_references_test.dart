import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';

import 'lyrics_plugin_test_helpers.dart';

const _id = 'plugin-tttttttttttt';

void main() {
  late LibraryDatabase db;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    await db.insertLyricsPlugin(
      _id,
      pluginSpec(kind: PluginKind.translate),
      now: 1,
    );
    await db.customStatement(
      'UPDATE lyrics_plugins SET removed_at = 5 WHERE install_id = ?',
      [_id],
    );
  });
  tearDown(() => db.close());

  Future<bool> recordExists() async => await db.lyricsPluginById(_id) != null;

  test('clear translations keeps a record saved lyrics still name', () async {
    await insertTranslation(db, _id);
    await seedPluginReferences(
      db,
      _id,
      found: false,
      notFound: false,
      pin: true,
    );
    expect(await db.clearLyricTranslations(), 1);
    expect(await recordExists(), isTrue);
  });

  test('clear translations deletes the record nothing else names', () async {
    await insertTranslation(db, _id);
    expect(await db.clearLyricTranslations(), 1);
    expect(await recordExists(), isFalse);
  });

  test('clear translations leaves live records alone', () async {
    await db.insertLyricsPlugin('plugin-llllllllllll', pluginSpec(), now: 1);
    await db.clearLyricTranslations();
    expect(await db.lyricsPluginById('plugin-llllllllllll'), isNotNull);
  });

  test('clear online lyrics keeps a record a translation names', () async {
    await insertTranslation(db, _id);
    await db.clearOnlineLyrics();
    expect(await recordExists(), isTrue);
    await db.clearLyricTranslations();
    expect(await recordExists(), isFalse);
  });

  test('clear online lyrics deletes an unreferenced removed record', () async {
    await db.clearOnlineLyrics();
    expect(await recordExists(), isFalse);
  });

  test('clear saved lyrics keeps a record a translation names', () async {
    await insertTranslation(db, _id);
    await db.customStatement(
      'INSERT INTO online_lyrics (cache_key, provider_id, status, remote_id, '
      "plain_text, fetched_at) VALUES ('k', '\$_id', 'found', 'r', 't', 1)",
    );
    await db.clearLyricsPluginSavedLyrics(_id);
    expect(await recordExists(), isTrue);
    await db.clearLyricTranslations();
    expect(await recordExists(), isFalse);
  });

  test('a translate id is refused a source preference', () async {
    await db.customStatement(
      'UPDATE lyrics_plugins SET removed_at = NULL WHERE install_id = ?',
      [_id],
    );
    expect(
      await db.setLyricsSourceEnabled(_id, true),
      LyricsPluginWrite.skipped,
    );
    expect(await countRows(db, 'lyrics_source_prefs'), 0);
  });
}
