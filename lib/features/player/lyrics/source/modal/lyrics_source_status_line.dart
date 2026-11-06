import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../../../../core/settings/settings_provider.dart';
import '../../../../../l10n/l10n.dart';
import '../../../now_playing/now_playing_modal_navigation.dart';
import '../../../../../shared/settings_routes.dart';
import '../../lyrics_action_runner.dart';
import 'lyrics_source_modal_run.dart';

/// One line under the choice rows that says why no lyrics show, with the one
/// button that can fix it (turn on automatic search, retry). Empty while
/// lyrics show, when the song has lyrics off, or while a state has nothing to
/// say. With [loaded] false only the neutral "Checking lyrics sources…" line
/// shows, with no counts and no button.
class LyricsSourceStatusLine extends ConsumerWidget {
  const LyricsSourceStatusLine({
    super.key,
    required this.source,
    required this.messenger,
    required this.loaded,
  });

  final LyricsSourceResolution source;
  final ScaffoldMessengerState? messenger;
  final bool loaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (!loaded) return _Line(text: l10n.lyricsSourceModalLoading);
    final status = source.status;
    final entries = ref.watch(lyricsSourcesProvider);
    final enabled = entries.where((e) => e.enabled).toList();
    final autoAllowed = ref.watch(
      settingsProvider.select((s) => s.onlineLyrics.autoAllowed),
    );
    final target = lyricsTargetOfSong(ref, status.uri);

    String? text;
    Widget? button;
    String? note;
    switch (status) {
      case LyricsSearching():
        text = enabled.isEmpty
            ? l10n.lyricsSourceSearching
            : l10n.lyricsSourceStatusSearching(enabled.length);
      case LyricsNone(reason: LyricsNoneReason.noLyrics):
        if (entries.isEmpty) {
          text = l10n.lyricsSourceStatusNoSource;
        } else if (enabled.isEmpty) {
          text = l10n.lyricsSourceStatusAllOff;
        } else if (!autoAllowed) {
          text = l10n.lyricsSourceStatusAutoOff;
          button = TextButton(
            // The modal stays open: the notice opens above it and the line
            // updates when automatic search is on.
            onPressed: () => _turnOnAutomatic(context),
            child: Text(l10n.lyricsSourceStatusTurnOnAuto),
          );
        } else {
          text = l10n.lyricsSourceNone;
          if (target != null && !target.isAutoSearchable) {
            note = l10n.lyricsAutoNeedsTags;
          }
        }
      case LyricsNone(reason: LyricsNoneReason.notFound):
        text = l10n.lyricsSourceStatusNotFound(enabled.length);
      case LyricsNone(reason: LyricsNoneReason.error):
        text = l10n.lyricsSourceStatusFailed;
        button = TextButton(
          onPressed: () => closeStackThenRun(
            context,
            source: source,
            messenger: messenger,
            action: (runner) => runner.retry(),
          ),
          child: Text(l10n.lyricsRetry),
        );
      case LyricsNone(reason: LyricsNoneReason.paused):
        // The status does not say which sources are paused.
        text = l10n.lyricsSourcePaused;
      case LyricsNone(reason: LyricsNoneReason.instrumental):
        text = l10n.lyricsInstrumental;
      case LyricsNone(reason: LyricsNoneReason.off) ||
          LyricsFound() ||
          LyricsReading():
        break;
    }
    if (text == null) return const SizedBox.shrink();
    return _Line(text: text, trailing: button, note: note);
  }

  void _turnOnAutomatic(BuildContext context) {
    final runner = LyricsActionRunner.snapshot(
      context,
      source: source,
      messenger: messenger,
    );
    unawaited(
      runner.enableAutomatic(
        // Runs after the consent dialog: the modal may be gone by then.
        onOpenSettings: () {
          if (!context.mounted) return;
          leaveNowPlayingTo(
            context,
            settingsFocusLocation(SettingsAnchor.playbackLyrics),
          );
        },
        tellNeedsTags: false,
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text, this.trailing, this.note});

  final String text;
  final Widget? trailing;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: style),
          if (trailing != null)
            Align(alignment: Alignment.centerLeft, child: trailing),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
