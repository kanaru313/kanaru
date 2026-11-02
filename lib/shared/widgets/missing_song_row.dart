import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import 'context_menu_region.dart';
import 'favorite_button.dart';
import 'song_card.dart';
import 'song_row_view.dart';

/// Opacity of a row whose file is not in the library.
const _opacity = 0.6;

/// A row for a song whose file is not in the library: the library song row
/// ([SongRowView]), dimmed, with a crossed-out note for a cover, the file name
/// and "Not in library". It never plays.
///
/// The row is always a focus stop (Tab reaches it) and paints the theme's
/// `focusColor` over its card while focused from the keyboard, like the ink
/// of a row that plays. With [onMenu], a right click, a long press, the Menu
/// key or Shift+F10 open the screen's menu for it.
class MissingSongRow extends StatefulWidget {
  const MissingSongRow({
    super.key,
    required this.path,
    this.detail = '',
    this.leading,
    this.badge,
    this.trailing,
    this.showFavorite = false,
    this.onMenu,
  });

  /// The file; its last segment is the title.
  final String path;

  /// The third line, e.g. the "date - time" of a play.
  final String detail;

  /// Drawn before the cover, e.g. a drag handle or a rank.
  final Widget? leading;

  /// Drawn above the duration slot (see [SongRowView.badge]).
  final Widget? badge;

  /// Drawn at the end of the row, e.g. a remove button.
  final Widget? trailing;

  /// Shows a heart that can only take the file out of Favorites: a file
  /// outside the library cannot be liked.
  final bool showFavorite;

  /// Opens the screen's menu for the row; no menu when null.
  final ContextMenuOpen? onMenu;

  @override
  State<MissingSongRow> createState() => _MissingSongRowState();
}

class _MissingSongRowState extends State<MissingSongRow> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    final row = Opacity(
      opacity: _opacity,
      child: SongRowView(
        title: path.split('/').last,
        artist: context.l10n.playlistNotInLibrary,
        detail: widget.detail,
        coverPlaceholderIcon: AppIcons.musicOff,
        leading: widget.leading,
        badge: widget.badge,
        trailing: widget.trailing,
        heart: widget.showFavorite
            ? FavoriteButton(
                path: path,
                iconSize: 20,
                compact: true,
                canAdd: false,
              )
            : null,
      ),
    );
    // The row has no ink well to take focus (it does not play), so it is a
    // focus stop of its own; the Menu key needs focus inside the region.
    return ContextMenuRegion(
      onOpen: widget.onMenu,
      child: FocusableActionDetector(
        onShowFocusHighlight: (show) => setState(() => _highlighted = show),
        child: Stack(
          // The row keeps the list's constraints, as without the highlight.
          fit: StackFit.passthrough,
          children: [
            row,
            // Outside the Opacity, so the highlight is as strong as on any
            // other row.
            if (_highlighted)
              Positioned.fill(
                child: IgnorePointer(
                  // Same geometry as the SongCardFrame of the row.
                  child: Padding(
                    padding: songCardPadding,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: Theme.of(context).focusColor,
                        shape: songCardShape,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
