import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/player_service.dart';

/// Seek step for the arrow keys.
const _seekStep = Duration(seconds: 5);

/// Whether a text input has focus, so plain letters and arrows belong to it.
bool isTextInputFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// App-wide playback keys: Space plays/pauses, ←/→ seek by 5 s, Ctrl+S
/// toggles shuffle, Ctrl+R cycles repeat.
///
/// Sits between the app's default shortcuts and every route, so key events
/// bubbling up from the focused widget reach it before the default
/// Space → activate mapping. Space therefore plays/pauses even while a
/// button has focus (Enter still presses the button). Text fields are left
/// alone so typing and caret movement keep working; widgets that handle
/// these keys themselves (sliders, menus) also still get them first.
class PlayerShortcuts extends ConsumerWidget {
  const PlayerShortcuts({super.key, required this.child});

  final Widget child;

  KeyEventResult _onKey(WidgetRef ref, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (_onControlKey(ref, event, keyboard) case final result?) return result;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.space &&
        key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    if (isTextInputFocused()) return KeyEventResult.ignored;
    // Nothing to control: let Space press buttons and arrows move focus.
    if (ref.read(playerServiceProvider).queue.isEmpty) {
      return KeyEventResult.ignored;
    }

    final player = ref.read(playerServiceProvider.notifier);
    if (key == LogicalKeyboardKey.space) {
      // Holding Space must not toggle over and over, nor press the button.
      if (event is KeyDownEvent) player.playPause();
    } else {
      player.seekBy(
        key == LogicalKeyboardKey.arrowLeft ? -_seekStep : _seekStep,
      );
    }
    return KeyEventResult.handled;
  }

  /// Ctrl+S and Ctrl+R; `null` for any other key, left to [_onKey].
  KeyEventResult? _onControlKey(
    WidgetRef ref,
    KeyEvent event,
    HardwareKeyboard keyboard,
  ) {
    if (!keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return null;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.keyS && key != LogicalKeyboardKey.keyR) {
      return null;
    }
    if (isTextInputFocused() || ref.read(playerServiceProvider).queue.isEmpty) {
      return KeyEventResult.ignored;
    }
    // One toggle per press, not one per auto-repeat.
    if (event is KeyDownEvent) {
      final player = ref.read(playerServiceProvider.notifier);
      key == LogicalKeyboardKey.keyS
          ? player.toggleShuffle()
          : player.cycleRepeat();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) => _onKey(ref, event),
      child: child,
    );
  }
}
