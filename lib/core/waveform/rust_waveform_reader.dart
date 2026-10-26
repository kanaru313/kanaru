import '../../src/rust/api/waveform.dart' as native;
import '../native/rust_library.dart';
import 'waveform.dart';

/// [WaveformReader] backed by the Rust decoder. The native library loads on
/// the first job.
class RustWaveformReader implements WaveformReader {
  /// [cacheDirectory] is the waveform folder; `null` reads without a disk
  /// cache.
  const RustWaveformReader(this.cacheDirectory);

  final String? cacheDirectory;

  @override
  Future<int> beginJob() async {
    await ensureRustLibraryLoaded();
    return native.beginWaveformJob();
  }

  @override
  Future<WaveformReadResult> read(String path, int job) async {
    await ensureRustLibraryLoaded();
    final result = await native.loadWaveform(
      path: path,
      cacheDir: cacheDirectory ?? '',
      job: job,
    );
    return switch (result.status) {
      native.WaveformStatus.ready when result.levels.isNotEmpty =>
        WaveformFound(
          Waveform(
            levels: result.levels,
            length: Duration(milliseconds: result.durationMs),
          ),
        ),
      // Ready without levels is a clip too short to draw; no decoder and a
      // broken file answer the same way every time.
      native.WaveformStatus.ready ||
      native.WaveformStatus.unsupported ||
      native.WaveformStatus.failed => const WaveformAbsent(),
      native.WaveformStatus.busy ||
      native.WaveformStatus.cancelled => const WaveformRetry(),
    };
  }

  @override
  void cancel(int job) => native.cancelWaveform(job: job);
}
