/// One lookup in flight and the abandon checks of everyone waiting on it.
class LookupFlight {
  LookupFlight(bool Function()? first) : callers = [first];

  /// One entry per caller; `null` for a caller that never abandons.
  final List<bool Function()?> callers;
  late final Future<void> done;

  bool abandoned() => callers.every((check) => check != null && check());
}
