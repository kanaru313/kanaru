import 'package:material_ui/material_ui.dart';

import 'queue_row_actions.dart';

/// The controls of a queue row that can hold keyboard focus.
enum QueueRowControl {
  /// The row itself (what a tap plays).
  row,

  /// The remove button, which only exists in the focus order while the row
  /// shows its actions.
  remove,
}

/// Keeps keyboard focus on the same queue entry when the list rebuilds after
/// the playing track changes.
///
/// Rows are numbered from the playing track, so an advance remounts them and
/// the focused row's element disappears with its focus. The tracker
/// remembers which entry had focus and which control of the row
/// ([QueueRowControl]); the list arms it ([arm]) in the build that follows a
/// queue change, and the row for that entry takes focus back, on that same
/// control, as it mounts.
class QueueRowFocusTracker {
  int? _focusedEntry;
  int? _restoreEntry;
  QueueRowControl? _restoreControl;

  /// Asks the focused row which of its controls has focus; set by that row.
  QueueRowControl? Function()? _controlProbe;

  /// Entry of the queue row that has focus (the row or something in it).
  int? get focusedEntry => _focusedEntry;

  /// Remembers the focused entry for the rows mounted until [disarm].
  void arm() {
    _restoreEntry = _focusedEntry;
    _restoreControl = _controlProbe?.call();
  }

  /// Forgets the entry again; a row mounted later (scrolled back into view)
  /// must not take focus.
  void disarm() => _restoreEntry = null;

  /// Whether the row of [entry] is the one to restore (and then forgets it).
  bool _takeRestore(int entry) {
    if (_restoreEntry != entry) return false;
    _restoreEntry = null;
    return true;
  }
}

/// Wraps one queue row: reports its focus to the [tracker] and, when it
/// mounts right after the list was armed for its entry, takes focus back.
/// Carries the row's [ValueKey], so it must be the outermost widget of the
/// row.
class QueueRowFocus extends StatefulWidget {
  QueueRowFocus({
    required this.entry,
    required this.tracker,
    required this.child,
  }) : super(key: ValueKey(entry));

  /// The entry in the opened queue the row shows.
  final int entry;
  final QueueRowFocusTracker tracker;
  final Widget child;

  @override
  State<QueueRowFocus> createState() => _QueueRowFocusState();
}

class _QueueRowFocusState extends State<QueueRowFocus> {
  final _node = FocusNode(
    debugLabel: 'queue row',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    final tracker = widget.tracker;
    final restore = tracker._takeRestore(widget.entry);
    final control = tracker._restoreControl ?? QueueRowControl.row;
    // Focus can only be requested once the row is in the tree.
    if (restore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restore(control, 2));
    }
  }

  /// The focusable controls of the row: the row itself and, once it shows
  /// them, its remove button.
  List<FocusNode> get _controls => _node.traversalDescendants.toList();

  /// Which control [node] is: the remove button is the one inside the row's
  /// actions; anything else is the row.
  QueueRowControl _roleOf(FocusNode node) =>
      node.context?.findAncestorWidgetOfExactType<QueueRowActions>() != null
      ? QueueRowControl.remove
      : QueueRowControl.row;

  /// The control that has focus; `null` when focus is on no control of the
  /// row, say in its menu.
  QueueRowControl? _focusedControl() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || !mounted || !primary.ancestors.contains(_node)) {
      return null;
    }
    return _roleOf(primary);
  }

  /// Focuses [control]. The remove button only becomes focusable after the
  /// row has focus and shows it, so when it is not there yet the row takes
  /// focus and the next frame tries again, [tries] times in all.
  void _restore(QueueRowControl control, int tries) {
    if (!mounted) return;
    final controls = _controls;
    final exact = controls.where((c) => _roleOf(c) == control).firstOrNull;
    if (exact != null) {
      exact.requestFocus();
      return;
    }
    controls.firstOrNull?.requestFocus();
    if (tries > 1) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _restore(control, tries - 1),
      );
    }
  }

  @override
  void dispose() {
    if (widget.tracker._controlProbe == _focusedControl) {
      widget.tracker._controlProbe = null;
    }
    _node.dispose();
    super.dispose();
  }

  /// Focus left for a route above the page (the row menu): the row keeps its
  /// claim, since the menu's action may remount it.
  bool _inRowMenu() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null || !mounted) return false;
    final route = ModalRoute.of(focusContext);
    return route != null && route != ModalRoute.of(context);
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _node,
    onFocusChange: (focused) {
      final tracker = widget.tracker;
      if (focused) {
        tracker._focusedEntry = widget.entry;
        tracker._controlProbe = _focusedControl;
      } else if (tracker._focusedEntry == widget.entry && !_inRowMenu()) {
        tracker._focusedEntry = null;
        tracker._controlProbe = null;
      }
    },
    child: widget.child,
  );
}
