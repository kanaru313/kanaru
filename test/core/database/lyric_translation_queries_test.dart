import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyric_translation_queries.dart';

LyricTranslationsCompanion _row(
  String provider, {
  String hash = 'h1',
  String lang = 'vi',
  String json = '{"a":"b"}',
}) => LyricTranslationsCompanion.insert(
  contentHash: hash,
  provider: provider,
  targetLang: lang,
  linesJson: json,
  createdAt: 1,
);

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('save replaces only the row with the same key', () async {
    await db.saveLyricTranslation(_row('google', json: '{"a":"1"}'));
    await db.saveLyricTranslation(_row('deepl', json: '{"a":"2"}'));
    await db.saveLyricTranslation(_row('deepl', json: '{"a":"3"}'));
    final rows = await db.watchLyricTranslations('h1', 'vi').first;
    final byProvider = {for (final r in rows) r.provider: r.linesJson};
    expect(byProvider, {'google': '{"a":"1"}', 'deepl': '{"a":"3"}'});
  });

  test('watch filters by hash and language and emits after a save', () async {
    final emissions = <int>[];
    final sub = db
        .watchLyricTranslations('h1', 'vi')
        .listen((rows) => emissions.add(rows.length));
    await pumpEventQueue();
    await db.saveLyricTranslation(_row('google'));
    await db.saveLyricTranslation(_row('google', lang: 'en'));
    await db.saveLyricTranslation(_row('google', hash: 'h2'));
    await pumpEventQueue();
    await sub.cancel();
    expect(emissions.first, 0);
    expect(emissions.last, 1);
  });

  test('song target can be set, changed and cleared', () async {
    final values = <String?>[];
    final sub = db.watchSongTranslationTarget('h1').listen(values.add);
    await pumpEventQueue();
    await db.setSongTranslationTarget('h1', 'vi');
    await pumpEventQueue();
    await db.setSongTranslationTarget('h1', 'en');
    await pumpEventQueue();
    await db.setSongTranslationTarget('h1', null);
    await pumpEventQueue();
    await sub.cancel();
    expect(values, [null, 'vi', 'en', null]);
  });

  test('stats count rows and sum UTF-8 bytes', () async {
    const text = '{"a":"Xin chào"}';
    await db.saveLyricTranslation(_row('google', json: text));
    await db.saveLyricTranslation(_row('deepl', json: '{}'));
    final stats = await db.watchLyricTranslationStats().first;
    expect(stats.count, 2);
    expect(stats.bytes, text.runes.length + 1 + 2); // "à" is 2 bytes
  });

  test('stats stream updates after a save and a clear', () async {
    const json = '{"a":"b"}';
    final seen = <(int, int)>[];
    final sub = db.watchLyricTranslationStats().listen(
      (s) => seen.add((s.count, s.bytes)),
    );
    await pumpEventQueue();
    await db.saveLyricTranslation(_row('google', json: json));
    await pumpEventQueue();
    await db.clearLyricTranslations();
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, [(0, 0), (1, json.length), (0, 0)]);
  });

  test('stats are zero when empty', () async {
    final stats = await db.watchLyricTranslationStats().first;
    expect((stats.count, stats.bytes), (0, 0));
  });

  test('clear returns the count and leaves song targets', () async {
    await db.saveLyricTranslation(_row('google'));
    await db.saveLyricTranslation(_row('deepl'));
    await db.setSongTranslationTarget('h1', 'vi');
    expect(await db.clearLyricTranslations(), 2);
    expect(await db.watchLyricTranslations('h1', 'vi').first, isEmpty);
    expect(await db.watchSongTranslationTarget('h1').first, 'vi');
    expect(await db.clearLyricTranslations(), 0);
  });

  test('deleting tracks leaves translations', () async {
    final rootId = (await db.addRoots(['/m'], now: 1)).single;
    await db.upsertTracks([
      TracksCompanion.insert(
        rootId: rootId,
        path: '/m/a.flac',
        mtimeMs: 1,
        sizeBytes: 1,
        title: 'A',
        addedAt: 1,
        updatedAt: 1,
      ),
    ]);
    await db.saveLyricTranslation(_row('google'));
    final ids = (await db.select(db.tracks).get()).map((t) => t.id);
    await db.deleteTracksById(ids);
    expect(await db.select(db.tracks).get(), isEmpty);
    expect(await db.watchLyricTranslations('h1', 'vi').first, hasLength(1));
  });
}
