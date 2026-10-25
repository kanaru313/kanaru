import 'dart:async';
import 'dart:typed_data';

import 'package:kanaru/core/waveform/waveform.dart';

/// [WaveformReader] whose reads end when a test says so. Records what the
/// controller asks, and mimics the native side: a job cancelled before its
/// read starts ends at once with [WaveformRetry].
class FakeWaveformReader implements WaveformReader {
  /// Job ids handed out, in order.
  final begun = <int>[];

  /// Paths and job ids of every `read`, in order.
  final reads = <String>[];
  final readJobs = <int>[];

  /// Job ids passed to `cancel`, in order.
  final cancels = <int>[];

  /// When set, `beginJob` waits for it, to cancel a job that is starting.
  Completer<void>? holdBegin;

  /// Paths whose read throws.
  final throwing = <String>{};

  var _lastJob = 0;
  final _cancelledJobs = <int>{};
  final _pending = <String, Completer<WaveformReadResult>>{};
  final _jobOfPath = <String, int>{};

  @override
  Future<int> beginJob() async {
    final hold = holdBegin;
    if (hold != null) await hold.future;
    final job = ++_lastJob;
    begun.add(job);
    return job;
  }

  @override
  Future<WaveformReadResult> read(String path, int job) {
    reads.add(path);
    readJobs.add(job);
    if (throwing.contains(path)) {
      return Future<WaveformReadResult>.error(StateError('cannot read'));
    }
    if (_cancelledJobs.contains(job)) {
      return Future<WaveformReadResult>.value(const WaveformRetry());
    }
    final completer = Completer<WaveformReadResult>();
    _pending[path] = completer;
    _jobOfPath[path] = job;
    return completer.future;
  }

  @override
  void cancel(int job) {
    cancels.add(job);
    _cancelledJobs.add(job);
    final path = _jobOfPath.entries
        .where((e) => e.value == job && _pending.containsKey(e.key))
        .map((e) => e.key)
        .firstOrNull;
    if (path != null) _pending.remove(path)!.complete(const WaveformRetry());
  }

  /// Whether a read of [path] is in flight.
  bool isReading(String path) => _pending.containsKey(path);

  /// Ends the in-flight read of [path] with [result].
  void finish(String path, WaveformReadResult result) =>
      _pending.remove(path)!.complete(result);

  /// Ends the in-flight read of [path] with a waveform of one level.
  void found(String path, {int level = 100}) => finish(
    path,
    WaveformFound(
      Waveform(
        levels: Uint8List.fromList([level]),
        length: const Duration(seconds: 1),
      ),
    ),
  );

  /// Every begun job was passed to `read`: that frees it on the native side.
  bool get everyBegunJobWasRead =>
      begun.toSet().difference(readJobs.toSet()).isEmpty;
}
