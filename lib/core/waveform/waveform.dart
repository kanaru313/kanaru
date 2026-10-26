import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The loudness of one track over time.
class Waveform {
  /// [levels] must not be empty.
  Waveform({required this.levels, required this.length})
    : assert(levels.isNotEmpty, 'a waveform has at least one level');

  /// Up to 1000 loudness levels from 0 to 255, evenly spaced over [length].
  final Uint8List levels;

  /// The decoded audio duration the levels span. It can differ a little from
  /// the player's duration (tags, VBR headers), so a view maps time against
  /// the player's duration and clamps.
  final Duration length;
}

/// The waveform of the track at [uri]. The uri tells a view which track the
/// waveform belongs to, so it never draws the previous track's bars.
typedef PlayingWaveform = ({String uri, Waveform waveform});

/// How one waveform read ended. The controller must tell a final answer
/// (remember it) from a temporary one (ask again later), so the reader
/// reports which it was instead of a bare `null`.
sealed class WaveformReadResult {
  const WaveformReadResult();
}

/// The levels of the file.
final class WaveformFound extends WaveformReadResult {
  const WaveformFound(this.waveform);

  final Waveform waveform;
}

/// The file has no waveform and asking again gives the same answer: no
/// decoder for it, a broken file, or a clip too short to draw. Remembered.
final class WaveformAbsent extends WaveformReadResult {
  const WaveformAbsent();
}

/// No answer this time: the read was cancelled, or the file could not be
/// read now (gone, unreadable mount, stalled, native side busy). Never
/// remembered; asked again only after a track change or a new waveform view.
final class WaveformRetry extends WaveformReadResult {
  const WaveformRetry();
}

/// Reads the waveform of an audio file. One job is begun, then read, and
/// every begun job id must be read (even a cancelled one): that is what
/// frees it on the native side.
abstract interface class WaveformReader {
  /// Starts a job and returns its id. Asynchronous because the native
  /// library may still have to load.
  Future<int> beginJob();

  /// Reads the file at [path] as job [job]. Never throws for a file problem;
  /// those are [WaveformAbsent] or [WaveformRetry].
  Future<WaveformReadResult> read(String path, int job);

  /// Stops [job]; its [read] ends with [WaveformRetry] soon. An unknown or
  /// finished id does nothing.
  void cancel(int job);
}

/// A reader that finds no waveform.
class NoWaveformReader implements WaveformReader {
  const NoWaveformReader();

  @override
  Future<int> beginJob() async => 0;

  @override
  Future<WaveformReadResult> read(String path, int job) async =>
      const WaveformAbsent();

  @override
  void cancel(int job) {}
}

/// Defaults to no waveforms; the app overrides it with the Rust reader at
/// startup.
final waveformReaderProvider = Provider<WaveformReader>(
  (ref) => const NoWaveformReader(),
);
