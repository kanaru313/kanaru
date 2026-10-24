import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/search/search_prefs_provider.dart';
import '../../features/player/now_playing/now_playing_open_provider.dart';
import 'top_bar_search_history_menu.dart';

/// Wraps the top bar search field and shows the recent searches in an overlay
/// panel under it while the field has focus and is empty. Keys: Up/Down pick a
/// row, Enter opens it, Esc closes the panel (it opens again on the next
/// focus or when the text is emptied).
class TopBarSearchHistoryHost extends ConsumerStatefulWidget {
  const TopBarSearchHistoryHost({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onPick,
    required this.child,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// A history row was chosen by tap or Enter.
  final ValueChanged<String> onPick;
  final Widget child;

  @override
  ConsumerState<TopBarSearchHistoryHost> createState() =>
      _TopBarSearchHistoryHostState();
}

class _TopBarSearchHistoryHostState
    extends ConsumerState<TopBarSearchHistoryHost> {
  final _panel = OverlayPortalController();
  final _link = LayerLink();

  /// Row picked with the arrow keys, or -1.
  int _selected = -1;
  bool _dismissed = false;
  bool _wasEmpty = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  List<String> get _history =>
      ref.read(searchPrefsProvider).value?.history ?? const [];

  void _onTextChanged() {
    final empty = widget.controller.text.isEmpty;
    if (empty != _wasEmpty) {
      _wasEmpty = empty;
      _dismissed = false;
    }
    _sync();
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) _dismissed = false;
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final show =
        widget.focusNode.hasFocus &&
        widget.controller.text.isEmpty &&
        !_dismissed &&
        _history.isNotEmpty &&
        !ref.read(nowPlayingOpenProvider);
    if (show == _panel.isShowing) return;
    _selected = -1;
    show ? _panel.show() : _panel.hide();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent || !_panel.isShowing) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final last = _history.length - 1;
    if (key == LogicalKeyboardKey.escape) {
      _dismissed = true;
      _sync();
    } else if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _selected = _selected >= last ? last : _selected + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _selected = _selected < 0 ? last : _selected - 1);
    } else if (key == LogicalKeyboardKey.enter &&
        _selected >= 0 &&
        _selected <= last) {
      widget.onPick(_history[_selected]);
    } else if (key == LogicalKeyboardKey.delete &&
        _selected >= 0 &&
        _selected <= last) {
      ref.read(searchPrefsProvider.notifier).remove(_history[_selected]);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(searchPrefsProvider, (prev, next) {
      // Rows shift when an entry goes: the highlight would sit on another one.
      final before = prev?.value?.history.length;
      if (before != next.value?.history.length && _selected != -1) {
        setState(() => _selected = -1);
      }
      _sync();
    });
    ref.listen(nowPlayingOpenProvider, (_, _) => _sync());
    return LayoutBuilder(
      builder: (context, constraints) => OverlayPortal(
        controller: _panel,
        overlayChildBuilder: (_) => CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          offset: const Offset(0, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: constraints.maxWidth.clamp(
                topBarSearchHistoryMinWidth,
                double.infinity,
              ),
              child: TopBarSearchHistoryMenu(
                selected: _selected,
                onPick: widget.onPick,
              ),
            ),
          ),
        ),
        child: CompositedTransformTarget(
          link: _link,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _onKey,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
