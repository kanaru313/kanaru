import 'dart:async';

import 'package:logging/logging.dart';

import '../database/cover_color_queries.dart';
import '../database/library_database.dart';
import 'cover_color_extractor.dart';

final _log = Logger('cover_colors');

/// Covers whose colors are worked out per native call.
const coverColorBatchSize = 32;

/// How one color round ended.
class CoverColorRoundResult {
  int done = 0, failed = 0;

  /// Why the round stopped before the last key, for the log.
  String? stoppedBecause;

  /// Time spent in the native color code and in the database.
  Duration nativeTime = Duration.zero, dbTime = Duration.zero;
}

/// Works out and stores the colors of the covers of the tracks under
/// [rootIds] that have none under the current algorithm, passing over the
/// keys in [skip], [coverColorBatchSize] at a time, on the low-priority
/// threads.
///
/// Before each batch it stops when [shouldStop] (the app is closing),
/// [shouldYield] (a rescan is waiting) or not [enabled] (the user turned
/// cover colors off), and a batch that comes back after the user turned
/// cover colors off is not stored. A key whose colors cannot be worked out is added to
/// [skip]; so is every key of a batch that outlasts [timeout], and the round
/// stops there and hands the native call, which may still be running, to
/// [onStuck]. Never throws: an
/// error is logged and ends the round.
Future<CoverColorRoundResult> runCoverColorRound({
  required LibraryDatabase db,
  required CoverColorExtractor extractor,
  required List<int> rootIds,
  required Set<String> skip,
  required Duration timeout,
  required bool Function() enabled,
  required bool Function() shouldYield,
  required bool Function() shouldStop,
  void Function(Future<List<CoverColorSample>> pending)? onStuck,
}) async {
  final result = CoverColorRoundResult();
  try {
    final queryTime = Stopwatch()..start();
    final keys = [
      for (final key in await db.coverKeysNeedingColors(rootIds))
        if (!skip.contains(key)) key,
    ];
    result.dbTime += queryTime.elapsed;
    for (var i = 0; i < keys.length; i += coverColorBatchSize) {
      final why = shouldStop()
          ? 'app closing'
          : shouldYield()
          ? 'rescan requested'
          : !enabled()
          ? 'cover colors turned off'
          : null;
      if (why != null) {
        result.stoppedBecause = why;
        break;
      }
      final batch = keys.sublist(
        i,
        i + coverColorBatchSize < keys.length
            ? i + coverColorBatchSize
            : keys.length,
      );
      final nativeTime = Stopwatch()..start();
      final List<CoverColorSample> samples;
      final pending = extractor.extract(batch, background: true);
      try {
        samples = await pending.timeout(timeout);
      } on TimeoutException {
        onStuck?.call(pending);
        result.nativeTime += nativeTime.elapsed;
        skip.addAll(batch);
        result.failed += batch.length;
        result.stoppedBecause = 'color batch took over $timeout';
        _log.warning(result.stoppedBecause);
        break;
      }
      result.nativeTime += nativeTime.elapsed;
      // Turned off while the batch ran: store nothing more.
      if (!enabled()) {
        result.stoppedBecause = 'cover colors turned off';
        break;
      }
      final good = <CoverColorSample>[];
      for (final sample in samples) {
        if (sample.ok) {
          good.add(sample);
        } else {
          skip.add(sample.key);
        }
      }
      // A key the extractor left out of its answer is not tried again either.
      final answered = {for (final sample in samples) sample.key};
      for (final key in batch) {
        if (!answered.contains(key)) skip.add(key);
      }
      result
        ..done += good.length
        ..failed += batch.length - good.length;
      final writeTime = Stopwatch()..start();
      await db.upsertCoverColors(good);
      result.dbTime += writeTime.elapsed;
    }
  } catch (error, stackTrace) {
    result.stoppedBecause = 'error: $error';
    _log.warning('Cover color round failed', error, stackTrace);
  }
  return result;
}
