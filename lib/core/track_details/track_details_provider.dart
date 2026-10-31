import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_startup.dart';
import '../database/track_details_queries.dart';
import 'track_details.dart';

/// Details of the library track with the given id; emits again when its row
/// changes (a rescan, a cover) or a play is written, not for writes to other
/// tracks. Null once the track is gone.
final trackDetailsProvider = StreamProvider.autoDispose
    .family<TrackDetails?, int>((ref, id) {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(null);
      final out = StreamController<TrackDetails?>();
      StreamSubscription<TrackPlayTotals>? totals;
      final rows = db.watchTrackDetails(id).distinct().listen((row) {
        totals?.cancel();
        totals = null;
        if (row == null) {
          out.add(null);
          return;
        }
        totals = db
            .watchTrackPlayTotals(row.path)
            .listen(
              (t) => out.add(
                TrackDetails.fromRow(
                  row,
                  playCount: t.count,
                  firstPlayedAt: t.firstPlayedAt,
                  lastPlayedAt: t.lastPlayedAt,
                ),
              ),
              onError: out.addError,
            );
      }, onError: out.addError);
      ref.onDispose(() {
        rows.cancel();
        totals?.cancel();
        out.close();
      });
      return out.stream;
    });
