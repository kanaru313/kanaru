import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/playlist_add_queries.dart';
import '../../../core/database/playlist_providers.dart';
import '../../../core/database/playlist_rows.dart';
import '../../../l10n/l10n.dart';
import '../scroll_ink_surface.dart';
import 'add_to_playlist_dialog.dart';
import 'playlist_name_dialog.dart';
import 'playlist_picker_add_step.dart';
import 'playlist_picker_footer.dart';
import 'playlist_picker_view.dart';

/// The multi-select picker; open it through `showPlaylistPicker`.
///
/// The selection (ticked playlists, named new playlists) lives here. The
/// name dialog opens above this route, so cancelling it keeps every tick.
/// Nothing is written: Add pops a plan for the caller to carry out.
class PlaylistPickerDialog extends ConsumerStatefulWidget {
  const PlaylistPickerDialog({
    super.key = const ValueKey('playlist-picker'),
    required this.db,
    required this.paths,
    required this.label,
    this.excludePlaylistId,
    this.suggestedName,
    this.viaKeyboard = false,
  });

  final LibraryDatabase db;
  final Future<List<String>> paths;
  final String label;
  final int? excludePlaylistId;

  /// Name offered by the first "New playlist"; null offers the default.
  final String? suggestedName;

  /// Opened from the keyboard: focus lands on "New playlist…" at once.
  final bool viaKeyboard;

  @override
  ConsumerState<PlaylistPickerDialog> createState() =>
      _PlaylistPickerDialogState();
}

class _PlaylistPickerDialogState extends ConsumerState<PlaylistPickerDialog> {
  final Set<int> _ticked = {};
  final List<PendingPlaylist> _pending = [];
  final FocusNode _pendingFocus = FocusNode(debugLabel: 'pending playlist');
  late final _scope = FocusScopeNode(
    debugLabel: 'PlaylistPickerDialog',
    onKeyEvent: (_, event) => _onKey(event),
  );
  int? _songCount;
  Map<int, int> _overlaps = const {};
  bool _busy = false;
  bool _naming = false;

  @override
  void initState() {
    super.initState();
    _loadHints();
  }

  @override
  void dispose() {
    _scope.dispose();
    _pendingFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isNav =
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.tab;
    // Nothing in the picker has focus yet: the first navigation key lands on
    // the first row instead of moving from nowhere.
    if (isNav && _scope.focusedChild == null) {
      _scope.nextFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The song count and "has K of them" hints, once the paths are read.
  Future<void> _loadHints() async {
    try {
      final paths = await widget.paths;
      final overlaps = await widget.db.playlistOverlapCounts(paths);
      if (!mounted) return;
      setState(() {
        _songCount = paths.length;
        _overlaps = overlaps;
      });
    } catch (_) {
      // Hints only: Add awaits the paths again and reports the failure.
    }
  }

  /// Ticked playlists that still exist, under their current names.
  List<PlaylistSummary> get _liveTicked => [
    for (final p in ref.read(playlistSummariesProvider).value ?? const [])
      if (p.id != widget.excludePlaylistId && _ticked.contains(p.id)) p,
  ];

  List<String> get _newNames => [
    for (final p in _pending.reversed)
      if (p.on) p.name,
  ];

  int get _selected => _liveTicked.length + _pending.where((p) => p.on).length;

  bool get _current => mounted && ModalRoute.of(context)!.isCurrent;

  void _toggle(PlaylistSummary playlist) => setState(() {
    if (!_ticked.remove(playlist.id)) _ticked.add(playlist.id);
  });

  void _togglePending(int i) => setState(
    () => _pending[i] = (name: _pending[i].name, on: !_pending[i].on),
  );

  Future<void> _newPlaylist() async {
    if (_naming || _busy) return;
    _naming = true;
    final l10n = context.l10n;
    final suffix = _pending.isEmpty ? '' : ' ${_pending.length + 1}';
    final name = await showPlaylistNameDialog(
      context,
      title: l10n.playlistCreateTitle,
      confirmLabel: l10n.playlistCreateConfirm,
      initialName: _pending.isEmpty && widget.suggestedName != null
          ? widget.suggestedName!
          : '${l10n.playlistDefaultName}$suffix',
      message: l10n.playlistPickerNameMessage,
    );
    _naming = false;
    if (name == null || !mounted) return;
    setState(() => _pending.insert(0, (name: name, on: true)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pendingFocus.requestFocus();
    });
  }

  /// Reads the paths, asks about songs already there, then closes with the
  /// plan; inert meanwhile.
  Future<void> _add() async {
    if (_busy || _selected == 0) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      final paths = await widget.paths;
      if (!_current) return _idle();
      if (paths.isEmpty) return navigator.pop();
      final plan = await planPickerAdd(
        db: widget.db,
        paths: paths,
        liveTicked: () => _liveTicked,
        newNames: () => _newNames,
        isCurrent: () => _current,
        pickerContext: () => context,
      );
      // Cancelled, covered, or all chosen playlists gone: stay open.
      if (plan == null || !_current) return _idle();
      navigator.pop(plan);
    } catch (error, stack) {
      if (!_current) return _idle();
      navigator.pop(PlaylistAddPlan.failed(error, stack));
    }
  }

  /// Add gave up (route no longer on top): accept input again.
  void _idle() {
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.watch(playlistSummariesProvider);
    final count = _selected;
    final autofocusNew =
        widget.viaKeyboard || MediaQuery.accessibleNavigationOf(context);
    return PopScope(
      canPop: !_busy,
      child: FocusScope(
        node: _scope,
        autofocus: true,
        child: AlertDialog(
          title: PlaylistPickerHeader(label: widget.label, songCount: _songCount),
          content: SizedBox(
            width: 440,
            height: 420,
            child: Column(
              children: [
                // Rows scrolled under the title keep their ink in the list.
                Expanded(
                  child: ScrollInkSurface(
                    child: ref
                        .watch(playlistSummariesProvider)
                        .when(
                          data: (playlists) => PlaylistPickerView(
                            playlists: [
                              for (final p in playlists)
                                if (p.id != widget.excludePlaylistId) p,
                            ],
                            ticked: _ticked,
                            pending: _pending,
                            overlaps: _overlaps,
                            enabled: !_busy,
                            pendingFocus: _pendingFocus,
                            autofocusNew: autofocusNew,
                            onCreate: _newPlaylist,
                            onToggle: _toggle,
                            onTogglePending: _togglePending,
                            onSubmit: count == 0 || _busy ? () {} : _add,
                          ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) =>
                            Center(child: Text(l10n.libraryUnexpectedError)),
                      ),
                ),
              ),
              const SizedBox(height: 12),
              PlaylistPickerFooter(selected: count, busy: _busy, onAdd: _add),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
