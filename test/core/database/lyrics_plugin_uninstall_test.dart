import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';

import 'lyrics_plugin_test_helpers.dart';

void main() {
  late LibraryDatabase db;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    await db.insertLyricsPlugin(
      'plugin-a',
      pluginSpec(configSchema: '[{"key":"token"}]'),
      now: 1,
    );
    await db.insertLyricsPlugin(
      'plugin-b',
      pluginSpec(packageDir: 'plugin-b/v1-1'),
      now: 1,
    );
    await db.setLyricsSourceEnabled('plugin-a', true);
    await db.setLyricsSourceEnabled('plugin-b', true);
    await db.setLyricsPluginConfigValues('plugin-a', {'k': 'v'});
  });
  tearDown(() => db.close());

  test('unknown id reports missing and changes nothing', () async {
    final before = await snapshotPluginTables(db);
    final result = await db.uninstallLyricsPlugin('plugin-z', now: 9);
    expect(result.outcome, LyricsPluginUninstall.missing);
    expect(result.configSchema, isNull);
    expect(await snapshotPluginTables(db), before);
  });

  test('a second uninstall changes nothing and returns no schema', () async {
    await seedPluginReferences(db, 'plugin-a');
    await db.uninstallLyricsPlugin('plugin-a', now: 5);
    final before = await snapshotPluginTables(db);
    final again = await db.uninstallLyricsPlugin('plugin-a', now: 9);
    expect(again.outcome, LyricsPluginUninstall.alreadyRemoved);
    expect(again.configSchema, isNull);
    expect(await snapshotPluginTables(db), before);
    expect((await db.lyricsPluginById('plugin-a'))!.removedAt, 5);
  });

  test('with nothing saved the record is deleted', () async {
    await seedPluginReferences(db, 'plugin-a', found: false);
    final result = await db.uninstallLyricsPlugin('plugin-a', now: 9);
    expect(result.outcome, LyricsPluginUninstall.deleted);
    expect(result.configSchema, '[{"key":"token"}]');
    expect(await db.lyricsPluginById('plugin-a'), isNull);
    expect(await db.lyricsPluginDataFor('plugin-a'), isNull);
    expect(await countRows(db, 'online_lyrics'), 0);
    expect((await db.watchLyricsSourcePrefs().first).map((p) => p.providerId), [
      'plugin-b',
    ]);
  });

  for (final (label, found, pin, reject) in [
    ('a found row', true, false, false),
    ('a pin', false, true, false),
    ('a reject', false, false, true),
  ]) {
    test('$label keeps the record, marked removed', () async {
      await seedPluginReferences(
        db,
        'plugin-a',
        found: found,
        pin: pin,
        reject: reject,
      );
      final result = await db.uninstallLyricsPlugin('plugin-a', now: 9);
      expect(result.outcome, LyricsPluginUninstall.markedRemoved);
      expect(result.configSchema, '[{"key":"token"}]');
      final row = (await db.lyricsPluginById('plugin-a'))!;
      expect(row.removedAt, 9);
      // Data, preference and not-found rows are gone; the references stay.
      expect(await db.lyricsPluginDataFor('plugin-a'), isNull);
      expect(
        (await db.watchLyricsSourcePrefs().first).map((p) => p.providerId),
        ['plugin-b'],
      );
      expect(await countRows(db, 'online_lyrics'), found ? 1 : 0);
      expect(await countRows(db, 'lyrics_pins'), pin ? 1 : 0);
      expect(await countRows(db, 'online_lyrics_rejects'), reject ? 1 : 0);
    });
  }

  test('not-found rows go, found rows stay, other plugins untouched', () async {
    await seedPluginReferences(db, 'plugin-a');
    await seedPluginReferences(db, 'plugin-b');
    await db.uninstallLyricsPlugin('plugin-a', now: 9);
    final rows = await db
        .customSelect(
          'SELECT provider_id, status FROM online_lyrics ORDER BY 1, 2',
        )
        .get();
    expect(
      [for (final r in rows) (r.data['provider_id'], r.data['status'])],
      [('plugin-a', 'found'), ('plugin-b', 'found'), ('plugin-b', 'not_found')],
    );
    expect(await db.lyricsPluginDataFor('plugin-b'), isNotNull);
    expect((await db.lyricsPluginById('plugin-b'))!.removedAt, isNull);
  });

  for (final trigger in [
    ('removal mark', 'BEFORE UPDATE'),
    ('hard delete', 'BEFORE DELETE'),
  ]) {
    test(
      'a failure at the ${trigger.$1} leaves every table unchanged',
      () async {
        // found row => mark path; no references => delete path.
        await seedPluginReferences(
          db,
          'plugin-a',
          found: trigger.$1 == 'removal mark',
        );
        await db.customStatement(
          'CREATE TRIGGER block_${trigger.$1.split(' ').first} ${trigger.$2} '
          "ON lyrics_plugins BEGIN SELECT RAISE(ABORT, 'boom'); END",
        );
        final before = await snapshotPluginTables(db);
        expect(before.any((t) => t.startsWith('online_lyrics: [{')), isTrue);
        await expectLater(
          db.uninstallLyricsPlugin('plugin-a', now: 9),
          throwsA(isA<Exception>()),
        );
        expect(await snapshotPluginTables(db), before);
      },
    );
  }

  test('clearing online lyrics also deletes removed records only', () async {
    await seedPluginReferences(db, 'plugin-a');
    await db.uninstallLyricsPlugin('plugin-a', now: 9);
    await db.clearOnlineLyrics();
    expect(await db.lyricsPluginById('plugin-a'), isNull);
    expect(await db.lyricsPluginById('plugin-b'), isNotNull);
  });

  group('clearing a removed plugin', () {
    setUp(() async {
      await seedPluginReferences(db, 'plugin-a', pin: true);
      await db.uninstallLyricsPlugin('plugin-a', now: 5);
    });

    test('deletes the record only when nothing else points to it', () async {
      await db.clearLyricsPluginSavedLyrics('plugin-a');
      // The pin still names it.
      expect(await db.lyricsPluginById('plugin-a'), isNotNull);
      await db.customStatement('DELETE FROM lyrics_pins');
      await db.clearLyricsPluginSavedLyrics('plugin-a');
      expect(await db.lyricsPluginById('plugin-a'), isNull);
    });

    test('keeps the record while a found row remains', () async {
      await db.customStatement('DELETE FROM lyrics_pins');
      expect(await db.clearLyricsPluginSavedLyrics('plugin-b'), 0);
      expect(await db.lyricsPluginById('plugin-a'), isNotNull);
      expect(await db.clearLyricsPluginSavedLyrics('plugin-a'), 1);
      expect(await db.lyricsPluginById('plugin-a'), isNull);
    });

    test('a live record is never deleted by a clear', () async {
      await db.clearLyricsPluginSavedLyrics('plugin-b');
      expect(await db.lyricsPluginById('plugin-b'), isNotNull);
    });
  });
}
