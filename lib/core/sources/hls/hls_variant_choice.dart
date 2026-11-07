import 'hls_models.dart';
import 'hls_refusal.dart';

/// Picks the media playlist to play from a master playlist, preferring audio:
///
/// 1. audio-only variants (`CODECS` present, every codec audio): highest
///    `BANDWIDTH`;
/// 2. else `EXT-X-MEDIA:TYPE=AUDIO` renditions with a `URI`: the group named
///    by `AUDIO` of the highest-`BANDWIDTH` variant whose group has one; in
///    it `DEFAULT=YES`, else `AUTOSELECT=YES`, else the first listed;
/// 3. else variants that may carry audio (`CODECS` absent or with an audio
///    codec): lowest `BANDWIDTH`;
/// 4. else `noAudio`.
///
/// Ties go to the first listed. `EXT-X-I-FRAME-STREAM-INF` is never parsed
/// into a variant, so it is never chosen.
Uri chooseHlsVariant(HlsMasterPlaylist master) {
  HlsVariant? best;
  for (final variant in master.variants) {
    final codecs = variant.codecs;
    if (codecs == null || !codecs.every(_isAudioCodec)) continue;
    if (best == null || variant.bandwidth > best.bandwidth) best = variant;
  }
  if (best != null) return best.uri;

  final groups = <String, List<HlsRendition>>{};
  for (final rendition in master.renditions) {
    if (rendition.type == 'AUDIO' && rendition.uri != null) {
      (groups[rendition.groupId] ??= []).add(rendition);
    }
  }
  for (final variant in master.variants) {
    final group = groups[variant.audioGroup];
    if (group == null) continue;
    if (best == null || variant.bandwidth > best.bandwidth) best = variant;
  }
  if (best != null) {
    final group = groups[best.audioGroup]!;
    final chosen =
        group.where((r) => r.isDefault).firstOrNull ??
        group.where((r) => r.isAutoselect).firstOrNull ??
        group.first;
    return chosen.uri!;
  }

  for (final variant in master.variants) {
    final codecs = variant.codecs;
    if (codecs != null && !codecs.any(_isAudioCodec)) continue;
    if (best == null || variant.bandwidth < best.bandwidth) best = variant;
  }
  if (best != null) return best.uri;
  throw const HlsRefusal(HlsRefusalKind.noAudio);
}

const _audioCodecPrefixes = ['mp4a', 'ac-3', 'ec-3', 'opus', 'flac', 'alac'];

bool _isAudioCodec(String codec) {
  final lower = codec.toLowerCase();
  return _audioCodecPrefixes.any(lower.startsWith);
}
