import 'widgets/queue_actions_menu.dart';

/// What the menu of a song row can do.
sealed class TrackMenuChoice {
  const TrackMenuChoice();
}

/// One of the three queue rows.
class QueueChoice extends TrackMenuChoice {
  const QueueChoice(this.action);

  final QueueAction action;
}

class ShowArtistChoice extends TrackMenuChoice {
  const ShowArtistChoice();
}

class ShowAlbumChoice extends TrackMenuChoice {
  const ShowAlbumChoice();
}

class ShowInFileManagerChoice extends TrackMenuChoice {
  const ShowInFileManagerChoice();
}

/// Puts the song in Favorites ([favorite] true) or takes it out.
class FavoriteChoice extends TrackMenuChoice {
  const FavoriteChoice({required this.favorite});

  final bool favorite;
}
