import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kanaru/core/track_details/release_date.dart';
import 'package:kanaru/core/track_details/track_details.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/shared/song_modal/info/song_info_groups.dart';

final _now = DateTime(2026, 10, 31);
final _l10n = AppLocalizationsEn();

TrackDetails _details({
  String? localPath = '/m/Artist/Album/01 Song.flac',
  String? artist,
  int? year,
  String? releaseDateRaw,
  ReleaseDate? releaseDate,
  int? trackNo,
  int? trackTotal,
  int? durationMs,
  int? bitrate,
  int? sampleRate,
  int? bitDepth,
  int? channels,
  int sizeBytes = 0,
  String? language,
}) => TrackDetails(
  id: 1,
  title: 'Song',
  localPath: localPath,
  artist: artist,
  year: year,
  releaseDateRaw: releaseDateRaw,
  releaseDate: releaseDate,
  trackNo: trackNo,
  trackTotal: trackTotal,
  durationMs: durationMs,
  bitrate: bitrate,
  sampleRate: sampleRate,
  bitDepth: bitDepth,
  channels: channels,
  language: language,
  sizeBytes: sizeBytes,
  modifiedAtMs: DateTime(2025, 3, 4, 5, 6).millisecondsSinceEpoch,
  addedAtMs: DateTime(2025, 4, 5, 17, 8).millisecondsSinceEpoch,
);

SongInfoField _field(List<SongInfoGroup> groups, String id) =>
    groups.expand((g) => g.fields).firstWhere((f) => f.id == id);

List<SongInfoGroup> _build(TrackDetails d) =>
    buildSongInfoGroups(_l10n, d, now: _now);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('vi');
  });

  test('groups come in order Tags, Audio, File', () {
    expect(_build(_details()).map((g) => g.id), ['tags', 'audio', 'file']);
  });

  test('a song with no local file has no File group', () {
    expect(_build(_details(localPath: null)).map((g) => g.id), [
      'tags',
      'audio',
    ]);
  });

  test('unknown fields are hidden unless asked for', () {
    final tags = _build(_details(artist: 'A; B')).first;
    final shown = tags.visibleFields(showUnknown: false).map((f) => f.id);
    expect(shown, ['title', 'artist']);
    expect(
      tags.visibleFields(showUnknown: true),
      hasLength(tags.fields.length),
    );
    expect(_field([tags], 'album').isKnown, isFalse);
  });

  test('empty and blank text counts as unknown', () {
    final d = _details(artist: '   ');
    expect(_field(_build(d), 'artist').value, isNull);
  });

  test('track and disc read n/total', () {
    final g = _build(_details(trackNo: 3, trackTotal: 12));
    expect(_field(g, 'track').value, '3/12');
    expect(_field(_build(_details(trackNo: 3)), 'track').value, '3');
    expect(_field(_build(_details()), 'track').value, isNull);
  });

  test('release date is the stored text, with chips from its parse', () {
    final g = _build(
      _details(
        year: 2001,
        releaseDateRaw: '2008-11-14',
        releaseDate: const ReleaseDate(year: 2008, month: 11, day: 14),
      ),
    );
    final f = _field(g, 'release-date');
    expect(f.value, '2008-11-14');
    expect(f.chips, ['Nov 14, 2008', '18 years ago']);
  });

  test('release date falls back on the year while it is not stored', () {
    final f = _field(_build(_details(year: 2019)), 'release-date');
    expect(f.value, '2019');
    expect(f.chips, ['7 years ago']);
    expect(_field(_build(_details()), 'release-date').chips, isEmpty);
  });

  test('an unreadable stored date shows as written, chips from the year', () {
    final f = _field(
      _build(_details(year: 2001, releaseDateRaw: 'spring')),
      'release-date',
    );
    expect(f.value, 'spring');
    expect(f.chips, ['25 years ago']);
  });

  test('unparseable raw date with year still gets years-ago chip', () {
    for (final raw in ['spring', '   ']) {
      final f = _field(
        _build(_details(year: 2019, releaseDateRaw: raw)),
        'release-date',
      );
      expect(f.chips, ['7 years ago'], reason: raw);
    }
  });

  test('language shows its translated name', () {
    expect(
      _field(_build(_details(language: 'vie')), 'language').value,
      'Vietnamese',
    );
  });

  test('audio fields are formatted', () {
    final g = _build(
      _details(
        durationMs: 215000,
        bitrate: 320,
        sampleRate: 44100,
        bitDepth: 16,
        channels: 2,
      ),
    );
    expect(_field(g, 'duration').value, '3:35');
    expect(_field(g, 'format').value, 'FLAC');
    expect(_field(g, 'bitrate').value, '320 kbps');
    expect(_field(g, 'sample-rate').value, '44.1 kHz');
    expect(_field(g, 'bit-depth').value, '16 bit');
    expect(_field(g, 'channels').value, 'Stereo');
  });

  test('sample rate without a fraction and channel plurals', () {
    expect(
      _field(_build(_details(sampleRate: 48000)), 'sample-rate').value,
      '48 kHz',
    );
    expect(_field(_build(_details(channels: 1)), 'channels').value, 'Mono');
    expect(
      _field(_build(_details(channels: 6)), 'channels').value,
      '6 channels',
    );
  });

  test('missing or zero audio facts are unknown', () {
    final g = _build(_details(bitrate: 0));
    expect(_field(g, 'bitrate').isKnown, isFalse);
    expect(_field(g, 'duration').isKnown, isFalse);
  });

  test('file fields: path as stored, size, dates', () {
    final g = _build(_details(sizeBytes: 5 * 1024 * 1024 + 300 * 1024));
    expect(_field(g, 'path').value, '/m/Artist/Album/01 Song.flac');
    expect(_field(g, 'size').value, '5.3 MB');
    expect(_field(g, 'modified').value, 'Mar 4, 2025 05:06');
    expect(_field(g, 'added').value, 'Apr 5, 2025 17:08');
  });

  test('sizes below a megabyte', () {
    expect(_field(_build(_details(sizeBytes: 512)), 'size').value, '512 B');
    expect(_field(_build(_details(sizeBytes: 2048)), 'size').value, '2 KB');
  });
}
