import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/lyrics.dart';
import '../../../core/lyrics/track_lyrics_preview_provider.dart';
import '../../../core/track_details/track_details_provider.dart';
import '../../../l10n/l10n.dart';
import '../../icons/app_icons.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/context_modal/context_modal_route.dart';
import '../info/wrap_anywhere.dart';
import '../song_modal_session.dart';

/// The whole lyrics of the song, one line per row. [lyrics] is the text the
/// Song info card showed when it was opened. Synced lyrics can show each
/// line's time (kept only while the page is open); the copy button puts the
/// plain text, without times, on the clipboard.
ContextModalPage songLyricsPage(
  SongModalSession session, {
  required String path,
  required Lyrics lyrics,
}) {
  final showTimes = ValueNotifier<bool>(false);
  return ContextModalPage(
    key: 'song-lyrics',
    headerBuilder: (context, nav) => Consumer(
      builder: (context, ref, _) {
        // The page below is unmounted while this one is on top. Watching
        // what it shows keeps that data loaded, so going back finds the
        // page as it was, at the same scroll offset.
        ref.watch(trackDetailsProvider(session.song.id));
        ref.watch(trackLyricsPreviewProvider(path));
        final l10n = context.l10n;
        return ContextModalTopBar(
          title: l10n.songLyricsPageTitle(session.song.title),
          onBack: nav.pop,
          actions: [
            if (lyrics.synced)
              ValueListenableBuilder<bool>(
                valueListenable: showTimes,
                builder: (context, on, _) => IconButton(
                  key: const ValueKey('song-lyrics-times'),
                  tooltip: on
                      ? l10n.songLyricsHideTimestamps
                      : l10n.songLyricsShowTimestamps,
                  isSelected: on,
                  icon: const Icon(AppIcons.schedule),
                  onPressed: () => showTimes.value = !on,
                ),
              ),
            IconButton(
              key: const ValueKey('song-lyrics-copy'),
              tooltip: l10n.songLyricsCopy,
              icon: const Icon(AppIcons.copy),
              onPressed: () => _copy(context, lyrics),
            ),
          ],
        );
      },
    ),
    bodyBuilder: (context, nav) => _LyricRows(lyrics, showTimes),
  );
}

Future<void> _copy(BuildContext context, Lyrics lyrics) async {
  final messenger = ScaffoldMessenger.of(context);
  final title = context.l10n.songLyricsCopied;
  await Clipboard.setData(
    ClipboardData(text: lyrics.lines.map((l) => l.text).join('\n')),
  );
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      appSnackBar(
        kind: AppSnackBarKind.success,
        title: title,
        duration: const Duration(milliseconds: 2000),
      ),
    );
}

/// The rows as a list that makes a row only when the list view asks for it,
/// so lyrics of ten thousand lines cost what the visible ones cost.
class _LyricRows extends ListBase<Widget> {
  _LyricRows(this._lyrics, this._showTimes);

  final Lyrics _lyrics;
  final ValueListenable<bool> _showTimes;

  @override
  int get length => _lyrics.lines.length;

  @override
  set length(int _) => throw UnsupportedError('read-only');

  @override
  Widget operator [](int index) => _LyricRow(
    line: _lyrics.lines[index],
    synced: _lyrics.synced,
    showTimes: _showTimes,
    first: index == 0,
    last: index == length - 1,
  );

  @override
  void operator []=(int index, Widget value) =>
      throw UnsupportedError('read-only');
}

class _LyricRow extends StatelessWidget {
  const _LyricRow({
    required this.line,
    required this.synced,
    required this.showTimes,
    required this.first,
    required this.last,
  });

  final LyricLine line;
  final bool synced;
  final ValueListenable<bool> showTimes;
  final bool first;
  final bool last;

  static String _clock(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = EdgeInsets.fromLTRB(20, first ? 12 : 0, 20, last ? 16 : 0);
    if (line.text.isEmpty) {
      return Padding(padding: pad, child: const SizedBox(height: 14));
    }
    return Padding(
      padding: pad,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: ValueListenableBuilder<bool>(
          valueListenable: showTimes,
          builder: (context, on, _) => Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (on && synced)
                SizedBox(
                  width: 52,
                  child: Text(
                    _clock(line.time),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  wrapAnywhere(line.text),
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
