import 'package:flutter/widgets.dart' show VoidCallback;

/// What the Most played modal's rows do. Each runs after the modal closed.
class MostPlayedModalHandlers {
  const MostPlayedModalHandlers({
    required this.play,
    required this.shuffle,
    required this.addToPlaylist,
    required this.addToFavorites,
    required this.exportAbsolute,
    required this.exportRelative,
  });

  final VoidCallback play;
  final VoidCallback shuffle;
  final VoidCallback addToPlaylist;
  final VoidCallback addToFavorites;
  final VoidCallback exportAbsolute;
  final VoidCallback exportRelative;
}
