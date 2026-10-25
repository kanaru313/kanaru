import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/format_duration.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/in_page_filter.dart';
import '../../../shared/widgets/expanding_search_bar.dart';

/// The bar over the songs of a detail page (album, artist, genre): an optional
/// [title], "N songs · length" and the filter button, whose box grows over
/// the count when opened but leaves the title in view. `Ctrl+F` opens it
/// through the page's filter host.
class SliverTracksToolbar extends StatelessWidget {
  const SliverTracksToolbar({
    super.key,
    required this.songCount,
    required this.durationMs,
    required this.filter,
    this.title,
  });

  final int songCount;

  /// Length of all the songs; null or zero is not shown.
  final int? durationMs;
  final InPageFilterController filter;

  /// Section heading at the start of the bar, such as "Songs"; the count and
  /// the filter come after it.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final durationMs = this.durationMs;
    final title = this.title;
    final muted = theme.colorScheme.onSurfaceVariant;
    final summary = [
      context.l10n.albumsSongCount(songCount),
      if (durationMs != null && durationMs > 0)
        formatDuration(Duration(milliseconds: durationMs)),
    ].join(' · ');

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, title == null ? 8 : 24, 24, 8),
        child: Row(
          children: [
            if (title != null) ...[
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(width: 24),
            ],
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
