import 'package:intl/intl.dart';

import '../../../core/track_details/track_details.dart';
import '../../../l10n/l10n.dart';
import '../../format_file_size.dart';
import 'song_info_model.dart';

/// The File group of [d]; the caller leaves it out for a track with no
/// local file.
SongInfoGroup songInfoFileGroup(
  AppLocalizations l10n,
  TrackDetails d,
  String path,
) {
  final dateTime = DateFormat.yMMMd(l10n.localeName).add_Hm();
  String when(int ms) =>
      dateTime.format(DateTime.fromMillisecondsSinceEpoch(ms));
  return SongInfoGroup(
    id: 'file',
    title: l10n.songInfoGroupFile,
    fields: [
      SongInfoField(
        id: 'path',
        label: l10n.songInfoLabelPath,
        value: infoText(path),
      ),
      SongInfoField(
        id: 'size',
        label: l10n.songInfoLabelSize,
        value: formatFileSize(l10n, d.sizeBytes),
      ),
      SongInfoField(
        id: 'modified',
        label: l10n.songInfoLabelModified,
        value: when(d.modifiedAtMs),
      ),
      SongInfoField(
        id: 'added',
        label: l10n.songInfoLabelAdded,
        value: when(d.addedAtMs),
      ),
    ],
  );
}
