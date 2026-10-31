import '../../../core/track_details/track_details.dart';
import '../../../l10n/l10n.dart';
import 'song_info_audio_group.dart';
import 'song_info_file_group.dart';
import 'song_info_model.dart';
import 'song_info_tags_group.dart';

export 'song_info_model.dart';

/// The Tags, Audio and File groups of [d], with every field in it (known or
/// not; the page decides what to hide). The File group is left out for a
/// track with no local file. Pure: [now] is only used for "N years ago".
List<SongInfoGroup> buildSongInfoGroups(
  AppLocalizations l10n,
  TrackDetails d, {
  required DateTime now,
}) {
  final path = d.localPath;
  return [
    songInfoTagsGroup(l10n, d, now: now),
    songInfoAudioGroup(l10n, d),
    if (path != null) songInfoFileGroup(l10n, d, path),
  ];
}
