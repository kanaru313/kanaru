import '../database/track_details_queries.dart';
import 'release_date.dart';

/// Everything the song details dialog shows about one library track.
class TrackDetails {
  const TrackDetails({
    required this.id,
    required this.title,
    required this.sizeBytes,
    required this.modifiedAtMs,
    required this.addedAtMs,
    this.localPath,
    this.artist,
    this.album,
    this.albumArtist,
    this.trackNo,
    this.trackTotal,
    this.discNo,
    this.discTotal,
    this.year,
    this.releaseDate,
    this.releaseDateRaw,
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
    this.playCount = 0,
    this.firstPlayedAt,
    this.lastPlayedAt,
  });

  /// Builds the model from a [row] and the play totals of its file.
  factory TrackDetails.fromRow(
    TrackDetailsRow row, {
    int playCount = 0,
    int? firstPlayedAt,
    int? lastPlayedAt,
  }) {
    final raw = row.extra.releaseDate;
    return TrackDetails(
      id: row.id,
      localPath: row.path,
      title: row.title,
      artist: row.artist,
      album: row.album,
      albumArtist: row.albumArtist,
      trackNo: row.trackNo,
      trackTotal: row.trackTotal,
      discNo: row.discNo,
      discTotal: row.discTotal,
      year: row.year,
      releaseDate: raw == null ? null : parseReleaseDate(raw),
      releaseDateRaw: raw,
      genre: row.genre,
      composer: row.composer,
      comment: row.comment,
      language: row.language,
      durationMs: row.durationMs,
      bitrate: row.bitrate,
      sampleRate: row.sampleRate,
      bitDepth: row.bitDepth,
      channels: row.channels,
      sizeBytes: row.sizeBytes,
      modifiedAtMs: row.mtimeMs,
      addedAtMs: row.addedAt,
      coverKey: row.coverKey,
      playCount: playCount,
      firstPlayedAt: firstPlayedAt,
      lastPlayedAt: lastPlayedAt,
    );
  }

  final int id;

  /// Absolute file path; null for a track with no local file.
  final String? localPath;
  final String title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? trackNo;
  final int? trackTotal;
  final int? discNo;
  final int? discTotal;

  /// The indexed year; the fallback while [releaseDate] is not stored yet.
  final int? year;

  /// Parsed from the stored raw tag value; null when not stored yet, absent
  /// in the tag or unparseable.
  final ReleaseDate? releaseDate;

  /// The release date as the tag wrote it; null when not stored yet or
  /// absent in the tag.
  final String? releaseDateRaw;
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
  final int modifiedAtMs;
  final int addedAtMs;
  final String? coverKey;
  final int playCount;
  final int? firstPlayedAt;
  final int? lastPlayedAt;
}
