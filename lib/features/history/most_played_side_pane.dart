import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/detail_page/collage_hero_cover.dart';
import '../../shared/widgets/detail_page/detail_side_pane.dart';
import '../../shared/widgets/playlist_cover.dart';

/// Seed of the collage: the same arrangement in the pane, the header and the
/// backdrop.
const _collageSeed = 'most-played';

/// Title, the range, the totals and the buttons, shared by the header and the
/// side pane.
class MostPlayedDetails extends StatelessWidget {
  const MostPlayedDetails({
    super.key,
    required this.rangeLine,
    required this.summary,
    required this.actions,
    required this.titleStyle,
    this.actionsAtEnd = false,
  });

  /// The range in words: "30 days · Sep 27 – Oct 26, 2026".
  final String rangeLine;

  /// "N songs · M listens"; null until the totals are read, so a pending read
  /// never claims "0 listens".
  final String? summary;

  /// Play, Shuffle and the more menu.
  final Widget actions;
  final TextStyle? titleStyle;

  /// Buttons at the right end of the column instead of the left.
  final bool actionsAtEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final summary = this.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.navMostPlayed,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(rangeLine, style: muted),
        if (summary != null) Text(summary, style: muted),
        const SizedBox(height: 16),
        Align(
          alignment: actionsAtEnd
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: actions,
        ),
      ],
    );
  }
}

/// Left column of the Most played page in a wide window: the collage of the
/// top-ranked covers as a hero card, then [MostPlayedDetails].
class MostPlayedSidePane extends StatelessWidget {
  const MostPlayedSidePane({
    super.key,
    required this.coverKeys,
    required this.rangeLine,
    required this.summary,
    required this.actions,
  });

  final List<String> coverKeys;
  final String rangeLine;
  final String? summary;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return DetailSidePane(
      cover: CollageHeroBackdrop(
        coverKeys: coverKeys,
        seed: _collageSeed,
        icon: AppIcons.mostPlayed,
      ),
      coverOverlay: CollageHeroCard(
        coverKeys: coverKeys,
        seed: _collageSeed,
        icon: AppIcons.mostPlayed,
      ),
      details: MostPlayedDetails(
        rangeLine: rangeLine,
        summary: summary,
        actions: actions,
        titleStyle: Theme.of(context).textTheme.headlineSmall,
        actionsAtEnd: true,
      ),
    );
  }
}

/// Header of the Most played page in a narrow window: a collage beside
/// [MostPlayedDetails]. A wide window shows [MostPlayedSidePane] instead.
class MostPlayedHeader extends StatelessWidget {
  const MostPlayedHeader({
    super.key,
    required this.coverKeys,
    required this.rangeLine,
    required this.summary,
    required this.actions,
  });

  final List<String> coverKeys;
  final String rangeLine;
  final String? summary;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Row(
        children: [
          PlaylistCover(
            coverKeys: coverKeys,
            size: 120,
            seed: _collageSeed,
            icon: AppIcons.mostPlayed,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: MostPlayedDetails(
              rangeLine: rangeLine,
              summary: summary,
              actions: actions,
              titleStyle: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ],
      ),
    );
  }
}
