import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/features/library/scan_result_snack_bar.dart';

void main() {
  final ended = DateTime(2026, 10, 19, 12);

  test('a result that just ended is announced', () {
    final now = ended.add(const Duration(seconds: 3));

    expect(
      isFreshScanResult(
        IndexerFinished(const ScanSummary(), at: ended),
        now: now,
      ),
      isTrue,
    );
    expect(isFreshScanResult(IndexerFailed('x', at: ended), now: now), isTrue);
  });

  test('an old result is not replayed', () {
    final now = ended.add(const Duration(minutes: 10));

    expect(
      isFreshScanResult(
        IndexerFinished(const ScanSummary(), at: ended),
        now: now,
      ),
      isFalse,
    );
    expect(isFreshScanResult(IndexerFailed('x', at: ended), now: now), isFalse);
  });

  test('progress and idle states are never announced', () {
    expect(isFreshScanResult(const IndexerIdle()), isFalse);
    expect(
      isFreshScanResult(
        const IndexerScanning(phase: ScanPhase.discovering, rootPath: '/m'),
      ),
      isFalse,
    );
  });
}
