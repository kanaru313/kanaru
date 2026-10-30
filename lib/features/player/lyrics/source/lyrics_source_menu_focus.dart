import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Where the focus goes when the lyrics source menu opens, however it
/// opened: the first item, or the header when that item is disabled. A menu
/// that holds the focus gets Escape; one that does not leaves it to the
/// screen behind, which would close Now Playing.
class LyricsSourceMenuFocus {
  /// The first item of the menu, for the arrow keys.
  final firstItem = FocusNode(debugLabel: 'Lyrics source: first item');

  /// The header, a place for the focus when the first item cannot take it.
  final header = FocusNode(
    debugLabel: 'Lyrics source: menu header',
    skipTraversal: true,
  );

  /// Moves the focus into the menu once the frame has built it; does nothing
  /// if the menu has closed or [isAlive] says the owner is gone by then.
  void focusAfterFrame({
    required bool Function() isAlive,
    required bool Function() isOpen,
  }) => SchedulerBinding.instance.addPostFrameCallback((_) {
    if (!isAlive() || !isOpen()) return;
    (firstItem.canRequestFocus && firstItem.context != null
            ? firstItem
            : header)
        .requestFocus();
  });

  void dispose() {
    firstItem.dispose();
    header.dispose();
  }
}
