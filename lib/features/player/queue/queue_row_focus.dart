import 'package:material_ui/material_ui.dart';

/// Keeps keyboard focus on the same queue entry when the list rebuilds after
/// the playing track changes.
///
/// Rows are numbered from the playing track, so an advance remounts them and
/// the focused row's element disappears with its focus. The tracker
/// remembers which entry had focus; the list arms it ([arm]) in the
/// build that follows a queue change, and the row for that entry takes focus
/// back as it mounts.
class QueueRowFocusTracker {
  int? _focusedEntry;
  int? _restoreEntry;

  /// Entry of the queue row that has focus (the row or something in it).
  int? get focusedEntry => _focusedEntry;

  /// Remembers the focused entry for the rows mounted until [disarm].
  void arm() => _restoreEntry = _focusedEntry;

  /// Forgets the entry again; a row mounted later (scrolled back into view)
  /// must not take focus.
  void disarm() => _restoreEntry = null;

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
    if (widget.tracker._takeRestore(widget.entry)) {
      // Focus can only be requested once the row is in the tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // The row itself, not the exact control inside it (say, its remove
        // button): rows are restyled next and will track the control then.
        _node.traversalDescendants.firstOrNull?.requestFocus();
      });
    }
  }

  @override
  void dispose() {
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
      } else if (tracker._focusedEntry == widget.entry && !_inRowMenu()) {
        tracker._focusedEntry = null;
      }
    },
    child: widget.child,
  );
}
