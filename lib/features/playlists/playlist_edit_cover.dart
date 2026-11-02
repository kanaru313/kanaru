import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/playlist_cover.dart';

const _coverSize = 200.0;

/// The playlist cover with a "Change cover · Coming soon" hint on hover. It
/// does nothing and cannot take focus: picking a cover is not built yet.
class PlaylistEditCover extends StatefulWidget {
  const PlaylistEditCover({
    super.key,
    required this.playlist,
    required this.coverKeys,
  });

  final PlaylistSummary playlist;
  final List<String> coverKeys;

  @override
  State<PlaylistEditCover> createState() => _PlaylistEditCoverState();
}

class _PlaylistEditCoverState extends State<PlaylistEditCover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final hint = '${l10n.playlistChangeCover} · ${l10n.contextModalComingSoon}';
    return ExcludeFocus(
      child: Semantics(
        label: l10n.playlistChangeCover,
        hint: l10n.contextModalComingSoon,
        child: MouseRegion(
          cursor: SystemMouseCursors.forbidden,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: _coverSize,
              height: _coverSize,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlaylistCover(
                    coverKeys: widget.coverKeys,
                    size: _coverSize,
                    radius: 0,
                    seed: 'playlist:${widget.playlist.id}',
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _hover ? 1 : 0,
                    child: ColoredBox(
                      color: scheme.scrim.withValues(alpha: 0.38),
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: ExcludeSemantics(
                              child: Text(
                                hint,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: scheme.onSurface),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
