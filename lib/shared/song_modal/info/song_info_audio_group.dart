import 'package:intl/intl.dart';

import '../../../core/track_details/track_details.dart';
import '../../../l10n/l10n.dart';
import '../../format_duration.dart';
import 'song_info_model.dart';

/// The Audio group of [d]. The format is the file extension.
SongInfoGroup songInfoAudioGroup(AppLocalizations l10n, TrackDetails d) {
  final path = d.localPath;
  final dot = path == null ? -1 : path.lastIndexOf('.');
  final slash = path == null ? -1 : path.lastIndexOf('/');
  final extension = path != null && dot > slash + 1
      ? path.substring(dot + 1)
      : '';
  return SongInfoGroup(
    id: 'audio',
    title: l10n.songInfoGroupAudio,
    fields: [
      SongInfoField(
        id: 'duration',
        label: l10n.songInfoLabelDuration,
        value: infoCount(
          d.durationMs,
          (ms) => formatDuration(Duration(milliseconds: ms)),
        ),
      ),
      SongInfoField(
        id: 'format',
        label: l10n.songInfoLabelFormat,
        value: extension.isEmpty ? null : extension.toUpperCase(),
      ),
      SongInfoField(
        id: 'bitrate',
        label: l10n.songInfoLabelBitrate,
        value: infoCount(d.bitrate, l10n.songInfoKbps),
      ),
      SongInfoField(
        id: 'sample-rate',
        label: l10n.songInfoLabelSampleRate,
        value: infoCount(
          d.sampleRate,
          (hz) => l10n.songInfoKhz(
            NumberFormat('#,##0.###', l10n.localeName).format(hz / 1000),
          ),
        ),
      ),
      SongInfoField(
        id: 'bit-depth',
        label: l10n.songInfoLabelBitDepth,
        value: infoCount(d.bitDepth, l10n.songInfoBits),
      ),
      SongInfoField(
        id: 'channels',
        label: l10n.songInfoLabelChannels,
        value: infoCount(
          d.channels,
          (n) => switch (n) {
            1 => l10n.songInfoMono,
            2 => l10n.songInfoStereo,
            _ => l10n.songInfoChannelsMany(n),
          },
        ),
      ),
    ],
  );
}
