import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the cover pass of a scan is running, and how far it got. Apart
/// from the indexer state: the library is usable while covers are made, and
/// a rescan may start at any time (the pass then yields).
sealed class CoverPassState {
  const CoverPassState();
}

class CoverPassIdle extends CoverPassState {
  const CoverPassIdle();
}

class CoverPassRunning extends CoverPassState {
  const CoverPassRunning({required this.done, required this.total});

  /// Tracks looked at so far in this pass.
  final int done;

  /// Tracks waiting for their cover when the pass started.
  final int total;
}

/// Set by the indexer only.
class CoverPassNotifier extends Notifier<CoverPassState> {
  @override
  CoverPassState build() => const CoverPassIdle();

  void report(int done, int total) =>
      state = CoverPassRunning(done: done, total: total);

  void finish() => state = const CoverPassIdle();
}

final coverPassProvider = NotifierProvider<CoverPassNotifier, CoverPassState>(
  CoverPassNotifier.new,
);
