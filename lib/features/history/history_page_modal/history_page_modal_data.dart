import 'package:flutter/widgets.dart' show VoidCallback;

import '../../../shared/widgets/context_modal/context_modal_nav.dart';

/// What the History modal's rows do. Each runs after the modal has closed
/// except [openAdvanced], which pushes the page.
class HistoryPageModalHandlers {
  const HistoryPageModalHandlers({
    required this.play,
    required this.shuffle,
    required this.addToPlaylist,
    required this.openMostPlayed,
    required this.exportAbsolute,
    required this.exportRelative,
    this.clear,
    this.openAdvanced,
  });

  final VoidCallback play;
  final VoidCallback shuffle;
  final VoidCallback addToPlaylist;
  final VoidCallback openMostPlayed;
  final VoidCallback exportAbsolute;
  final VoidCallback exportRelative;

  /// Asks which part to clear (above the modal), then closes it; `null`
  /// without a recorder to run the delete.
  final void Function(ContextModalNav nav)? clear;
  final void Function(ContextModalNav nav)? openAdvanced;
}
