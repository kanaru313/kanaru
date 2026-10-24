import 'dart:async';

/// Holds back the removal of swiped rows until the list is quiet.
///
/// Removing a row shifts the rows after it, and the reorderable list gives
/// every row a key that includes its index, so all of them remount. A row
/// that is being swiped at that moment would lose its gesture. The gate keeps
/// swiped entries pending (their rows render empty) until no pointer has
/// touched the list for [quiet], longer than a swipe takes to finish, then
/// removes them all at once.
///
/// Each swipe is recorded with a token naming the queue it happened in (see
/// [tokenOf]); the removal callback uses it to drop a swipe whose queue was
/// replaced meanwhile. A swipe cut short by closing the list mid-animation is
/// not recorded and stays undone.
class QueueSwipeGate {
  QueueSwipeGate({required this.remove, required this.tokenOf});

  /// Names the queue as it is now (its `original` list, whose identity
  /// changes when the queue is replaced and entries are renumbered).
  final Object Function() tokenOf;

  /// Quiet time before pending removals run: more than the swipe animation
  /// of a row (200 ms), so a row still sliding away is never remounted.
  static const quiet = Duration(milliseconds: 250);

  /// Removes these queue entries, each with the token of the queue it was
  /// swiped in. Called once the list is quiet, and when the gate is disposed.
  final void Function(Map<int, Object> entries) remove;

  final _pending = <int, Object>{};
  var _down = 0;
  Timer? _timer;

  /// Whether the row of [entry] was swiped and waits for its removal.
  bool isPending(int entry) => _pending.containsKey(entry);

  /// A pointer went down on the list.
  void pointerDown() {
    _down++;
    _timer?.cancel();
  }

  /// A pointer was lifted or cancelled.
  void pointerUp() {
    if (_down > 0) _down--;
    _arm();
  }

  /// The row of [entry] finished its swipe. [token] is [tokenOf] as it was
  /// when the swipe began, since the queue may be replaced while it ends.
  void swiped(int entry, Object token) {
    _pending[entry] = token;
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    if (_pending.isEmpty || _down > 0) return;
    _timer = Timer(quiet, _flush);
  }

  void _flush() {
    _timer = null;
    if (_pending.isEmpty) return;
    final entries = {..._pending};
    _pending.clear();
    remove(entries);
  }

  /// Runs what is still pending: a swipe the user finished is not undone by
  /// closing the sheet.
  void dispose() {
    _timer?.cancel();
    _flush();
  }
}
