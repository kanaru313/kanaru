import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../format_duration.dart';
import '../../icons/app_icons.dart';
import '../../in_page_filter.dart';
import '../expanding_search_bar.dart';

/// The bar over the songs of a detail page (album, artist, genre, playlist):
/// "N songs · length" and the filter button, whose box grows over the bar when opened.
/// `Ctrl+F` opens it through the page's filter host.
class SliverTracksToolbar extends StatelessWidget {
  const SliverTracksToolbar({
    super.key,
    required this.songCount,
    required this.durationMs,
    required this.filter,
  });

  final int songCount;

  /// Length of all the songs; null or zero is not shown.
  final int? durationMs;
  final InPageFilterController filter;

  @override
  Widget build(BuildContext context) {
    final durationMs = this.durationMs;
    final summary = [
      context.l10n.albumsSongCount(songCount),
      if (durationMs != null && durationMs > 0)
        formatDuration(Duration(milliseconds: durationMs)),
    ].join(' · ');
    return SliverToBoxAdapter(
      child: TracksToolbar(summary: summary, filter: filter),
    );
  }
}

/// [SliverTracksToolbar] as a box: a given [summary], the filter button and
/// optional [trailing] widgets right of it. The opened filter box covers the
/// summary but not the trailing widgets.
class TracksToolbar extends StatelessWidget {
  const TracksToolbar({
    super.key,
    required this.summary,
    required this.filter,
    this.trailing = const [],
  });

  final String summary;
  final InPageFilterController filter;

  /// Buttons to the right of the filter button.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: ExpandingSearchBar(
              controller: filter,
              child: Row(
                children: [
                  Icon(AppIcons.musicNoteOutlined, size: 20, color: muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}
