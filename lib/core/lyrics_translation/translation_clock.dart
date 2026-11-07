import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The time (epoch milliseconds) stamped on an explicit translation choice.
/// "Newest explicit choice wins" compares these stamps, so every writer reads
/// the same clock; tests replace it. A system clock set back makes a new
/// choice look older than an earlier one (accepted, see the lyrics docs).
final translationClockProvider = Provider<int Function()>(
  (ref) =>
      () => DateTime.now().millisecondsSinceEpoch,
);
