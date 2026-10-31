part of 'context_modal_shell.dart';

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

/// Keys the modal reacts to.
final _navKeys = {
  LogicalKeyboardKey.tab,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.space,
};

/// Key handling and focus of the shell.
extension on _ContextModalShellState {
  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !_navKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final moves =
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown;
    // Enter and Space belong to a text field that has focus.
    if (!moves && _textFieldHasFocus()) return KeyEventResult.ignored;
    _keyboardMode = true;
    // Nothing in the modal has focus yet: the first key press lands on the
    // first row instead of moving from nowhere.
    if (moves && _scope.focusedChild == null) {
      _scope.nextFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _textFieldHasFocus() {
    final focus = FocusManager.instance.primaryFocus?.context;
    return focus != null &&
        (focus.widget is EditableText ||
            focus.findAncestorWidgetOfExactType<EditableText>() != null);
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
}
