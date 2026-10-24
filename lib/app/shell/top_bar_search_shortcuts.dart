import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/in_page_filter_registry.dart';

/// `Ctrl+F` and `/` focus the top bar search field from anywhere.
///
/// A hardware keyboard handler, not a `Shortcuts` widget, so it works wherever
/// the focus is. It returns true only when it acts, so Space, the arrows,
/// `Ctrl+S` and `Ctrl+R` still reach the player shortcuts.
class TopBarSearchShortcuts {
  TopBarSearchShortcuts({
    required this.focusNode,
    required this.controller,
    required this.isNowPlayingOpen,
    InPageFilterRegistry? registry,
  }) : _registry = registry ?? InPageFilterRegistry.instance;

  final FocusNode focusNode;
  final TextEditingController controller;

  /// The Now Playing overlay hides the top bar; typing there would be blind.
  final bool Function() isNowPlayingOpen;

  final InPageFilterRegistry _registry;

  void attach() => HardwareKeyboard.instance.addHandler(_onKey);

  /// Must be called from `dispose`: a handler left behind runs in later tests
  /// and apps.
  void detach() => HardwareKeyboard.instance.removeHandler(_onKey);

  /// A `/` press this handler acted on is still held: its auto-repeats are
  /// consumed too, or they would type slashes into the field just focused.
  bool _slashHeld = false;

  bool _onKey(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.slash) {
      if (event is KeyUpEvent) {
        _slashHeld = false;
        return false;
      }
      if (event is KeyRepeatEvent) return _slashHeld;
    }
    if (event is! KeyDownEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isAltPressed || keyboard.isMetaPressed) return false;
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      if (!keyboard.isControlPressed || keyboard.isShiftPressed) return false;
      if (_blocked()) return false;
      return _openFind();
    }
    if (event.character == '/' && !keyboard.isControlPressed) {
      if (_blocked() || _inTextField()) return false;
      _focusTopBar();
      _slashHeld = true;
      return true;
    }
    return false;
  }

  bool _openFind() {
    // Already in the top bar field: select its text and stay.
    if (focusNode.hasFocus) {
      _focusTopBar();
      return true;
    }
    // Pressed again inside a page filter: leave it for the library search.
    if (!_registry.hasFocus && _registry.openTop()) return true;
    _focusTopBar();
    return true;
  }

  void _focusTopBar() {
    focusNode.requestFocus();
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  /// A dialog, menu or sheet is open, or Now Playing covers the top bar.
  bool _blocked() {
    if (isNowPlayingOpen()) return true;
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null && ModalRoute.of(context) is PopupRoute;
  }

  static bool _inTextField() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}
