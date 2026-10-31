import '../../../core/track_details/release_date.dart';
import '../../../core/track_details/track_details.dart';
import '../../../l10n/l10n.dart';
import '../../language_display_name.dart';
import 'release_date_chips.dart';
import 'song_info_model.dart';

/// The Tags group of [d].
SongInfoGroup songInfoTagsGroup(
  AppLocalizations l10n,
  TrackDetails d, {
  required DateTime now,
}) {
  // The tag as written, else the indexed year until the tag is read.
  final raw = infoText(d.releaseDateRaw);
  final year = d.year;
  final release =
      (raw == null ? null : parseReleaseDate(raw)) ??
      (year == null ? null : ReleaseDate(year: year));
  final language = infoText(d.language);
  SongInfoField f(String id, String label, String? value) =>
      SongInfoField(id: id, label: label, value: infoText(value));
  return SongInfoGroup(
    id: 'tags',
    title: l10n.songInfoGroupTags,
    fields: [
      f('title', l10n.songInfoLabelTitle, d.title),
      f('artist', l10n.songInfoLabelArtist, d.artist),
      f('album', l10n.songInfoLabelAlbum, d.album),
      f('album-artist', l10n.songInfoLabelAlbumArtist, d.albumArtist),
      f('genre', l10n.songInfoLabelGenre, d.genre),
      f('composer', l10n.songInfoLabelComposer, d.composer),
      SongInfoField(
        id: 'release-date',
        label: l10n.songInfoLabelReleaseDate,
        value: raw ?? year?.toString(),
        chips: release == null
            ? const []
            : releaseDateChipLabels(l10n, release, now: now),
      ),
      f('track', l10n.songInfoLabelTrack, infoNumber(d.trackNo, d.trackTotal)),
      f('disc', l10n.songInfoLabelDisc, infoNumber(d.discNo, d.discTotal)),
      f(
        'language',
        l10n.songInfoLabelLanguage,
        language == null ? null : languageDisplayName(l10n, language),
      ),
      f('comment', l10n.songInfoLabelComment, d.comment),
    ],
  );
}
