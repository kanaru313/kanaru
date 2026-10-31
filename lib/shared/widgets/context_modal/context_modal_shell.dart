import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import 'context_modal_dialog_frame.dart';
import 'context_modal_frame_scope.dart';
import 'context_modal_nav.dart';
import 'context_modal_page.dart';
import 'context_modal_sheet_frame.dart';

/// Width below which the modal becomes a bottom sheet.
const double contextModalSheetBelow = 600;

/// Slide distance and duration of a page change.
const double _slideDistance = 24;
const Duration _slideDuration = Duration(milliseconds: 200);

class _BackIntent extends Intent {
  const _BackIntent({required this.closeAtRoot});

  /// Esc closes at the first page; Backspace leaves the modal open.
  final bool closeAtRoot;
}

class _BackAction extends Action<_BackIntent> {
  _BackAction(this.shell);

  final _ContextModalShellState shell;

  @override
  bool isEnabled(_BackIntent intent) {
    // Backspace belongs to a text field that has focus.
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus != null &&
        (focus.widget is EditableText ||
            focus.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }
    return shell._stack.length > 1 || intent.closeAtRoot;
  }

  @override
  Object? invoke(_BackIntent intent) {
    shell._pop();
    return null;
  }
}

/// The modal's content: the page stack, key handling and the frame choice.
/// The stack lives here, above the frame switch, so resizing keeps the page.
class ContextModalShell extends StatefulWidget {
  const ContextModalShell({
    super.key,
    required this.root,
    this.semanticLabel,
    this.viaKeyboard = false,
  });

  final ContextModalPage root;
  final String? semanticLabel;

  /// Opened from the keyboard: focus lands on the first row at once.
  final bool viaKeyboard;

  @override
  State<ContextModalShell> createState() => _ContextModalShellState();
}

class _ContextModalShellState extends State<ContextModalShell> {
  late final List<ContextModalPage> _stack = [widget.root];
  late final _scope = FocusScopeNode(
    debugLabel: 'ContextModal',
    onKeyEvent: (_, event) => _onKey(event),
  );

  /// Set when opened from the keyboard or once a navigation key was pressed
  /// inside; page changes then keep a focus target. A mouse never sets it.
  late bool _keyboardMode = widget.viaKeyboard;
  bool _forward = true;
  late final ContextModalNav _nav = ContextModalNav(
    push: _push,
    pop: _pop,
    close: _close,
  );

  @override
  void initState() {
    super.initState();
    // Opened from the keyboard: land on the first row, so arrows work at once.
    if (_keyboardMode) _focusFirstRow();
  }

  static final _navKeys = {
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
  };

  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !_navKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    _keyboardMode = true;
    final key = event.logicalKey;
    final moves =
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown;
    // Nothing in the modal has focus yet: the first key press lands on the
    // first row instead of moving from nowhere.
    if (moves && _scope.focusedChild == null) {
      _scope.nextFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Keyboard mode keeps a focus target after the page changed; pointer
  /// users get none.
  void _focusFirstRow() {
    // Two frames: the first drops focus from the page that is leaving.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _keyboardMode) {
          FocusManager.instance.primaryFocus?.unfocus();
          _scope.nextFocus();
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  void _push(ContextModalPage page) {
    if (!mounted) return;
    setState(() {
      _forward = true;
      _stack.add(page);
    });
    _focusFirstRow();
  }

  void _pop() {
    if (!mounted) return;
    if (_stack.length <= 1) return _close();
    setState(() {
      _forward = false;
      _stack.removeLast();
    });
    _focusFirstRow();
  }

  void _close([Object? result]) {
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final page = _stack.last;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isSheet = MediaQuery.sizeOf(context).width < contextModalSheetBelow;
    final content = AnimatedSwitcher(
      duration: reduce ? Duration.zero : _slideDuration,
      transitionBuilder: (child, animation) {
        if (reduce) return child;
        final incoming = child.key == ValueKey(page.key);
        final side = (_forward == incoming ? 1 : -1) * _slideDistance;
        // The outgoing page can neither be clicked nor focused mid-slide.
        return IgnorePointer(
          ignoring: !incoming,
          child: ExcludeFocus(
            excluding: !incoming,
            child: FadeTransition(
              opacity: animation,
              child: AnimatedBuilder(
                animation: animation,
                builder: (_, child) => Transform.translate(
                  offset: Offset(side * (1 - animation.value), 0),
                  child: child,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(page.key),
        child: Builder(builder: (context) => page.build(context, _nav)),
      ),
    );
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: widget.semanticLabel ?? context.l10n.contextModalLabel,
      explicitChildNodes: true,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): _BackIntent(
            closeAtRoot: true,
          ),
          SingleActivator(LogicalKeyboardKey.backspace): _BackIntent(
            closeAtRoot: false,
          ),
          SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
            TraversalDirection.up,
          ),
          SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
            TraversalDirection.down,
          ),
        },
        child: Actions(
          actions: {_BackIntent: _BackAction(this)},
          child: FocusScope(
            node: _scope,
            autofocus: true,
            child: FocusTraversalGroup(
              child: ContextModalFrameScope(
                isSheet: isSheet,
                child: isSheet
                    ? ContextModalSheetFrame(onClose: _close, child: content)
                    : ContextModalDialogFrame(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
