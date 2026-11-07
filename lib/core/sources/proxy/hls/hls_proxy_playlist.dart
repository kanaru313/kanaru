import 'dart:typed_data';

import 'hls_proxy_names.dart';
import 'hls_snapshot.dart';

/// The playlist the proxy hands the player for [snapshot]: written afresh,
/// never copied from upstream, and every URI points back at the proxy.
///
/// [urlOf] turns a name relative to the item's proxy URL (`hls/<rev>/…`, see
/// `hls_proxy_names.dart`) into the absolute URL written into the playlist.
///
/// Only `EXT-X-VERSION`, `TARGETDURATION`, `MEDIA-SEQUENCE`, `PLAYLIST-TYPE`,
/// `DISCONTINUITY`, `KEY`, `MAP`, `EXTINF` and `ENDLIST` are written. A byte
/// range segment is written as a plain URL (the proxy fetches the range).
///
/// A `KEY` line is written whenever the key state changes: another key file,
/// another IV, or a key that stops applying (`METHOD=NONE`). The IV is kept as
/// the playlist gave it; without one the player derives it from the media
/// sequence, and two derived IVs are one state. A `MAP` is written under the
/// key state it had upstream, because the player reads the init section under
/// the key in force at its line: a clear init in front of an encrypted
/// segment is `MAP` then `KEY`, an encrypted one is `KEY` then `MAP`.
String writeHlsProxyPlaylist(
  HlsSnapshot snapshot,
  String Function(String name) urlOf,
) {
  final playlist = snapshot.playlist;
  final out = StringBuffer()
    ..writeln('#EXTM3U')
    ..writeln('#EXT-X-VERSION:7')
    ..writeln('#EXT-X-TARGETDURATION:${_targetDuration(snapshot)}')
    ..writeln('#EXT-X-MEDIA-SEQUENCE:${playlist.mediaSequence}')
    ..writeln('#EXT-X-PLAYLIST-TYPE:VOD');
  var inForce = HlsKeyState.none;
  int? initIndex;
  void keyLine(HlsKeyState wanted) {
    if (wanted == inForce) return;
    inForce = wanted;
    final index = wanted.keyIndex;
    if (index == null) {
      out.writeln('#EXT-X-KEY:METHOD=NONE');
      return;
    }
    final iv = wanted.iv;
    out.writeln(
      '#EXT-X-KEY:METHOD=AES-128,'
      'URI="${urlOf(hlsKeyName(snapshot.rev, index))}"'
      '${iv == null ? '' : ',IV=${_ivHex(iv)}'}',
    );
  }

  for (var i = 0; i < playlist.segments.length; i++) {
    final segment = playlist.segments[i];
    final layout = snapshot.layout.segments[i];
    if (segment.discontinuity) out.writeln('#EXT-X-DISCONTINUITY');
    final wantedInit = layout.initIndex;
    if (wantedInit != null && wantedInit != initIndex) {
      initIndex = wantedInit;
      keyLine(snapshot.layout.inits[wantedInit]);
      out.writeln(
        '#EXT-X-MAP:URI="${urlOf(hlsInitName(snapshot.rev, wantedInit))}"',
      );
    }
    keyLine(layout.keyState);
    final ext = hlsSegmentExt(segment.uri, hasInit: segment.init != null);
    out
      ..writeln(
        '#EXTINF:${(segment.duration.inMicroseconds / 1e6).toStringAsFixed(3)},',
      )
      ..writeln(urlOf(hlsSegmentName(snapshot.rev, i, ext)));
  }
  out.writeln('#EXT-X-ENDLIST');
  return out.toString();
}

/// The longest segment duration in whole seconds, rounded up (at least 1).
int _targetDuration(HlsSnapshot snapshot) {
  var longest = 0;
  for (final segment in snapshot.playlist.segments) {
    if (segment.duration.inMicroseconds > longest) {
      longest = segment.duration.inMicroseconds;
    }
  }
  final seconds = (longest + 999999) ~/ 1000000;
  return seconds < 1 ? 1 : seconds;
}

/// `0x` and the IV's bytes as lower-case hex digits.
String _ivHex(Uint8List iv) =>
    '0x${[for (final b in iv) b.toRadixString(16).padLeft(2, '0')].join()}';
