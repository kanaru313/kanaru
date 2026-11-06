import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics/lyrics.dart';
import '../../../../../core/lyrics/online/lyrics_source_names.dart';
import '../../../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import '../../../../../shared/lyrics_source_routes.dart';
import '../../../../../shared/widgets/selection_row.dart';
import '../../../now_playing/now_playing_modal_navigation.dart';
import '../../lyrics_action_runner.dart';
import '../lyrics_source_labels.dart';
import 'lyrics_save_targets_modal.dart';

/// Action rows under the choices: "Find lyrics online…" (or its all-off
/// variant), "Add an online lyrics source" when no plugin is installed, and
/// "Save lyrics…" while online lyrics or lyrics from the tags show.
///
/// Only the add row needs no song; the others show when [canChoose]. Nothing
/// shows until the sources are [loaded].
class LyricsSourceModalActions extends ConsumerStatefulWidget {
  const LyricsSourceModalActions({
    super.key,
    required this.source,
    required this.messenger,
    required this.canChoose,
    required this.loaded,
  });

  final LyricsSourceResolution source;
  final ScaffoldMessengerState? messenger;
  final bool canChoose;
  final bool loaded;

  @override
  ConsumerState<LyricsSourceModalActions> createState() =>
      _LyricsSourceModalActionsState();
}

class _LyricsSourceModalActionsState
    extends ConsumerState<LyricsSourceModalActions> {
  /// A Find lookup is under way (the consent notice or the picker is open), so
  /// a second tap opens nothing.
  bool _finding = false;

  Future<void> _find() async {
    if (_finding) return;
    _finding = true;
    try {
      await LyricsActionRunner.snapshot(
        context,
        source: widget.source,
        messenger: widget.messenger,
      ).findOnline(parentModalContext: context);
    } finally {
      _finding = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final messenger = widget.messenger;
    final canChoose = widget.canChoose;
    if (!widget.loaded) return const SizedBox.shrink();
    final l10n = context.l10n;
    final entries = ref.watch(lyricsSourcesProvider);
    final names = ref.watch(lyricsSourceNamesProvider);
    final on = entries.where((e) => e.enabled).length;
    final status = source.status;
    // Online lyrics and lyrics from the tags can be saved; a `.lrc` already is
    // the file.
    final found =
        status is LyricsFound &&
            (status.origin != null ||
                status.lyrics.source == LyricsSource.embedded)
        ? status
        : null;
    final chevron = Icon(
      AppIcons.chevronRight,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (entries.isEmpty)
          SelectionRow(
            title: l10n.lyricsSourceAddRow,
            subtitle: l10n.lyricsSourceAddRowSubtitle,
            leading: const Icon(AppIcons.add),
            trailing: chevron,
            selected: false,
            onTap: () => leaveNowPlayingTo(
              context,
              lyricsStoreRouteWithKind(lyricsSourcesStoreRoute, 'lyrics'),
            ),
          )
        else if (canChoose && on > 0)
          SelectionRow(
            title: l10n.lyricsFindOnline,
            subtitle: l10n.lyricsSourceFindRowSubtitle(on, entries.length - on),
            leading: const Icon(AppIcons.search),
            trailing: chevron,
            selected: false,
            // The modal stays open under the picker.
            onTap: () => unawaited(_find()),
          )
        else if (canChoose)
          SelectionRow(
            title: l10n.lyricsFindOnline,
            subtitle: l10n.lyricsSourceFindRowAllOff,
            leading: const Icon(AppIcons.search),
            trailing: chevron,
            selected: false,
            onTap: () => leaveNowPlayingTo(context, lyricsSourcesRoute),
          ),
        if (canChoose && found != null)
          SelectionRow(
            title: l10n.lyricsSaveRow,
            subtitle: l10n.lyricsSaveRowSubtitle(
              lyricsSourceDetail(l10n, found, names),
            ),
            leading: const Icon(AppIcons.lyricsSave),
            trailing: chevron,
            selected: false,
            onTap: () => showLyricsSaveTargetsModal(
              context,
              source: source,
              messenger: messenger,
            ),
          ),
      ],
    );
  }
}
