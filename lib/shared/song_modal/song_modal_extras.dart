import '../widgets/context_modal/context_modal_route.dart';

/// What a screen adds to the song modal of one of its rows: [actions] shown
/// before the links, and a quiet [headerNote] line under the album.
///
/// A destructive action (Remove from playlist) sets
/// `ContextModalAction.destructive`, which draws its label and icon in the
/// theme's error color.
class SongModalExtras {
  const SongModalExtras({this.actions = const [], this.headerNote});

  final List<ContextModalAction> actions;

  /// One short line under the album (for example the listen count); null
  /// leaves the header at three lines.
  final String? headerNote;
}

/// Builds the [SongModalExtras] of a row. Called in the gesture handler right
/// before the modal opens, never while the row builds: capture everything the
/// actions need (messenger, l10n, database, router, ids) inside it, and not
/// the row's own context later, since the row may be gone by the time an
/// action runs. Every action closes the modal first (`songModalCloseThen`).
typedef SongModalExtrasBuilder = SongModalExtras Function();
