import 'package:flutter_riverpod/flutter_riverpod.dart';

const defaultHistoryTopLimit = 100;
const maxCustomTopLimit = 1000;
const minCustomTopLimit = 1;

final mostPlayedTopLimitProvider =
    NotifierProvider<MostPlayedTopLimitNotifier, int>(
  MostPlayedTopLimitNotifier.new,
);

class MostPlayedTopLimitNotifier extends Notifier<int> {
  @override
  int build() => defaultHistoryTopLimit;

  void set(int limit) =>
      state = limit.clamp(minCustomTopLimit, maxCustomTopLimit);
}
