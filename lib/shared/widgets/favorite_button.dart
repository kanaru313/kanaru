import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_favorites.dart';
import '../../core/database/playlist_providers.dart';
import '../../core/database/track_cover_lookup.dart';
import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';

final _log = Logger('playlists');

void _say(ScaffoldMessengerState messenger, String text) => messenger
  ..clearSnackBars()
  ..showSnackBar(SnackBar(content: Text(text)));

/// Heart: puts the song at [path] in Favorites or takes it out; disabled
/// while [path] is null. Only a song that is a row of the library can be
/// added (the playlist matches entries to library rows by path); any song
/// can be taken out, so one that left the library is not stuck in Favorites.
///
/// The heart shows the wanted state at once and pops on each press. Presses
/// while a write runs only change the wanted state, and the writes run one
/// after another, so two quick presses end where they started.
class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({
    super.key,
    required this.path,
    this.iconSize,
    this.compact = false,
    this.color,
  });

  final String? path;
  final double? iconSize;

  /// A 28 px button with no padding, small enough to sit under the duration
  /// in the 48 px trailing slot of a list tile.
  final bool compact;

  /// Color of the heart while the song is not a favorite; null keeps the
  /// theme's. A favorite keeps its selected (primary) color.
  final Color? color;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton>
    with SingleTickerProviderStateMixin {
  /// The state the user asked for and the song it is for, shown instead of
  /// the stored one until the stored one agrees.
  String? _wantedPath;
  bool? _wanted;
  bool _writing = false;

  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  /// Shrinks a little, overshoots, then settles back to full size.
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.8,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.8,
        end: 1.25,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.25,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 40,
    ),
  ]).animate(_pop);

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  Future<void> _press(String path, bool shown) async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    if (!MediaQuery.disableAnimationsOf(context)) _pop.forward(from: 0);
    setState(() {
      _wantedPath = path;
      _wanted = !shown;
    });
    if (_writing) return;
    _writing = true;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      while (true) {
        final target = _wantedPath;
        final favorite = _wanted;
        if (target == null || favorite == null) break;
        try {
          if (favorite && await db.coverKeyOf(target) == null) {
            _say(messenger, l10n.playlistTrackNotInLibrary);
            _forgetIfStill(target, favorite);
          } else {
            await db.setFavorite(
              target,
              favorite: favorite,
              now: DateTime.now().millisecondsSinceEpoch,
            );
          }
        } catch (error, stack) {
          _log.severe('Changing the favorite of a song failed', error, stack);
          _say(messenger, l10n.playlistSaveFailed);
          _forgetIfStill(target, favorite);
        }
        // Done unless the user pressed again meanwhile (maybe on another
        // song): then the newer wish is written next.
        if (_wantedPath == null ||
            (_wantedPath == target && _wanted == favorite)) {
          break;
        }
      }
    } finally {
      // Rebuild so build() can drop the wanted state if the store already
      // caught up while the write was running.
      if (mounted) setState(() => _writing = false);
      _writing = false;
    }
  }

  /// Drops the wanted state after a failed write, unless the user asked for
  /// something newer meanwhile.
  void _forgetIfStill(String path, bool favorite) {
    if (_wantedPath != path || _wanted != favorite) return;
    _wantedPath = null;
    _wanted = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    // While the favorites load, a press could like a liked song again. A read
    // error does not block the heart: the writes set a state, never toggle.
    final loaded = ref.watch(
      favoritePathsProvider.select((s) => s.hasValue || s.hasError),
    );
    final enabled =
        path != null && loaded && ref.watch(libraryDatabaseProvider) != null;
    final stored =
        path != null &&
        ref.watch(
          favoritePathsProvider.select((s) => s.value?.contains(path) ?? false),
        );
    // Once the writes are done and the store caught up (or the song
    // changed), stop overriding it, so a change made elsewhere shows. The
    // output is the same, so no rebuild is needed.
    if (_wanted != null &&
        !_writing &&
        (_wantedPath != path || _wanted == stored)) {
      _wantedPath = null;
      _wanted = null;
    }
    final favorite = _wanted != null && _wantedPath == path ? _wanted! : stored;
    final l10n = context.l10n;
    return IconButton(
      isSelected: favorite,
      icon: ScaleTransition(
        scale: _scale,
        child: Icon(AppIcons.favoriteBorderRounded, color: widget.color),
      ),
      selectedIcon: ScaleTransition(
        scale: _scale,
        child: const Icon(AppIcons.favoriteRounded),
      ),
      iconSize: widget.iconSize,
      padding: widget.compact ? EdgeInsets.zero : null,
      constraints: widget.compact
          ? const BoxConstraints.tightFor(width: 28, height: 28)
          : null,
      tooltip: favorite ? l10n.favoritesRemove : l10n.nowPlayingFavorite,
      onPressed: enabled ? () => _press(path, favorite) : null,
    );
  }
}
