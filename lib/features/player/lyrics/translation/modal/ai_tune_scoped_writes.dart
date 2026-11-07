/// Writes of the tune modal to the song or the queue, one at a time and in
/// the order they were picked. One instance serves every field of a modal: a
/// model and a style picked in a row are two writes of one tune, so the
/// second must see the first.
class AiTuneScopedWrites {
  int _pending = 0;
  Future<void> _tail = Future.value();

  /// The values written through this instance, newest per key. They stand in
  /// for the stored values until those come back from the database; an entry
  /// the stored value has caught up with is dropped when read, and the modal
  /// clears them when the scope segment changes.
  final Map<String, String> written = {};

  /// A write is under way or waiting.
  bool get busy => _pending > 0;

  /// Completes when every write queued so far has ended.
  Future<void> get idle => _tail;

  /// Runs [job] after the writes before it. Completes with the error it threw,
  /// or null. [onChange] is told when [busy] may have changed.
  Future<Object?> enqueue(
    Future<void> Function() job, {
    void Function()? onChange,
  }) {
    _pending++;
    onChange?.call();
    final previous = _tail;
    final done = () async {
      await previous;
      try {
        await job();
        return null;
      } on Object catch (error) {
        return error;
      } finally {
        _pending--;
        onChange?.call();
      }
    }();
    _tail = done;
    return done;
  }
}
