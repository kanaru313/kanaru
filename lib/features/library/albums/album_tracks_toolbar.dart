import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/format_duration.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/in_page_filter.dart';
import '../../../shared/widgets/in_page_search_field.dart';

/// The bar over an album's tracks: "N songs · length" and the filter button.
/// An open filter shows its box under the bar, as wide as the list, with a
/// button that closes it. `Ctrl+F` opens it through the page's filter host.
class SliverAlbumTracksToolbar extends StatefulWidget {
  const SliverAlbumTracksToolbar({
    super.key,
    required this.album,
    required this.filter,
  });

  final AlbumSummary album;
  final InPageFilterController filter;

  @override
  State<SliverAlbumTracksToolbar> createState() =>
      _SliverAlbumTracksToolbarState();
}

class _SliverAlbumTracksToolbarState extends State<SliverAlbumTracksToolbar> {
  final _buttonFocus = FocusNode(debugLabel: 'album filter button');

  @override
  void dispose() {
    _buttonFocus.dispose();
    super.dispose();
  }

  /// Hands the focus back to the filter button once the box is gone.
  void _focusButton() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buttonFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final album = widget.album;
    final filter = widget.filter;
    final durationMs = album.durationMs;
    final muted = theme.colorScheme.onSurfaceVariant;
    final summary = [
      l10n.albumsSongCount(album.trackCount),
      if (durationMs != null && durationMs > 0)
        formatDuration(Duration(milliseconds: durationMs)),
    ].join(' · ');

    return SliverToBoxAdapter(
      child: ListenableBuilder(
        listenable: filter,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
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
                  IconButton(
                    focusNode: _buttonFocus,
                    isSelected: filter.isOpen,
                    icon: const Icon(AppIcons.search),
                    tooltip: l10n.inPageSearchOpen,
                    onPressed: filter.isOpen ? filter.close : filter.open,
                  ),
                ],
              ),
              if (filter.isOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: InPageSearchBox(
                          controller: filter,
                          width: double.infinity,
                          onEscape: _focusButton,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(AppIcons.close),
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                        onPressed: () {
                          filter.close();
                          _focusButton();
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
