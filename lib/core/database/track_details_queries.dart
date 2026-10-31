import 'package:drift/drift.dart' show Variable;

import 'extra_tags.dart';
import 'library_database.dart';

/// The columns of one track the details dialog shows, with `extra_tags`
/// already decoded.
class TrackDetailsRow {
  const TrackDetailsRow({
    required this.id,
    required this.path,
    required this.title,
    required this.sizeBytes,
    required this.mtimeMs,
    required this.addedAt,
    required this.extra,
    this.artist,
    this.album,
    this.albumArtist,
    this.trackNo,
    this.trackTotal,
    this.discNo,
    this.discTotal,
    this.year,
    this.genre,
    this.composer,
    this.comment,
    this.language,
    this.durationMs,
    this.bitrate,
    this.sampleRate,
    this.bitDepth,
    this.channels,
    this.coverKey,
  });

  final int id;
  final String path;
  final String title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? trackNo;
  final int? trackTotal;
  final int? discNo;
  final int? discTotal;
  final int? year;
  final String? genre;
  final String? composer;
  final String? comment;
  final String? language;
  final int? durationMs;
  final int? bitrate;
  final int? sampleRate;
  final int? bitDepth;
  final int? channels;
  final int sizeBytes;
  final int mtimeMs;
  final int addedAt;
  final String? coverKey;
  final ExtraTags extra;

  List<Object?> get _props => [
    id,
    path,
    title,
    artist,
    album,
    albumArtist,
    trackNo,
    trackTotal,
    discNo,
    discTotal,
    year,
    genre,
    composer,
    comment,
    language,
    durationMs,
    bitrate,
    sampleRate,
    bitDepth,
    channels,
    sizeBytes,
    mtimeMs,
    addedAt,
    coverKey,
    extra,
  ];

  // Value equality so `.distinct()` drops re-emits caused by writes to other
  // tracks or other columns.
  @override
  bool operator ==(Object other) {
    if (other is! TrackDetailsRow) return false;
    final a = _props, b = other._props;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_props);
}

/// Play totals of one file; zero and nulls when it was never played.
typedef TrackPlayTotals = ({int count, int? firstPlayedAt, int? lastPlayedAt});

extension TrackDetailsQueries on LibraryDatabase {
  /// Play totals of [path], emitting again after every play written.
  Stream<TrackPlayTotals> watchTrackPlayTotals(String path) {
    return customSelect(
      'SELECT play_count, first_played_at, last_played_at FROM play_stats '
      'WHERE path = ?1',
      variables: [Variable.withString(path)],
      readsFrom: {playStats},
    ).watch().map((rows) {
      if (rows.isEmpty) {
        return (count: 0, firstPlayedAt: null, lastPlayedAt: null);
      }
      final r = rows.first;
      return (
        count: r.read<int>('play_count'),
        firstPlayedAt: r.readNullable<int>('first_played_at'),
        lastPlayedAt: r.readNullable<int>('last_played_at'),
      );
    }).distinct();
  }

  /// The track with [id], fresh after every write to it; null once it is
  /// gone. Explicit columns: this is the only reader of `extra_tags`.
  Stream<TrackDetailsRow?> watchTrackDetails(int id) {
    final t = tracks;
    final query = selectOnly(t)
      ..addColumns([
        t.id,
        t.path,
        t.title,
        t.artist,
        t.album,
        t.albumArtist,
        t.trackNo,
        t.trackTotal,
        t.discNo,
        t.discTotal,
        t.year,
        t.genre,
        t.composer,
        t.comment,
        t.language,
        t.durationMs,
        t.bitrate,
        t.sampleRate,
        t.bitDepth,
        t.channels,
        t.sizeBytes,
        t.mtimeMs,
        t.addedAt,
        t.coverKey,
        t.extraTags,
      ])
      ..where(t.id.equals(id));
    return query.watchSingleOrNull().map(
      (r) => r == null
          ? null
          : TrackDetailsRow(
              id: r.read(t.id)!,
              path: r.read(t.path)!,
              title: r.read(t.title)!,
              artist: r.read(t.artist),
              album: r.read(t.album),
              albumArtist: r.read(t.albumArtist),
              trackNo: r.read(t.trackNo),
              trackTotal: r.read(t.trackTotal),
              discNo: r.read(t.discNo),
              discTotal: r.read(t.discTotal),
              year: r.read(t.year),
              genre: r.read(t.genre),
              composer: r.read(t.composer),
              comment: r.read(t.comment),
              language: r.read(t.language),
              durationMs: r.read(t.durationMs),
              bitrate: r.read(t.bitrate),
              sampleRate: r.read(t.sampleRate),
              bitDepth: r.read(t.bitDepth),
              channels: r.read(t.channels),
              sizeBytes: r.read(t.sizeBytes)!,
              mtimeMs: r.read(t.mtimeMs)!,
              addedAt: r.read(t.addedAt)!,
              coverKey: r.read(t.coverKey),
              extra: decodeExtraTags(r.read(t.extraTags)),
            ),
    );
  }
}
