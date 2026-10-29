import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../core/settings/settings_provider.dart';
import 'lyrics_credit_row.dart';
import 'lyrics_pulse_host.dart';
import 'plain_lyrics_view.dart';
import 'synced_lyrics_view.dart';
import 'translation/lyrics_translation_banner.dart';
import 'translation/translated_line_text.dart';

/// Lyrics of the playing track: synced lyrics follow playback, plain lyrics
/// are shown as they are. With translation on, each line carries its
/// translation (or a placeholder while it comes) and a banner reports a
/// failure. Online lyrics add their source credit under the lines; the
/// translation credit is on the header's translate button.
class LyricsFoundBody extends ConsumerWidget {
  const LyricsFoundBody({super.key, required this.found});

  final LyricsFound found;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = found.lyrics;
    final origin = found.origin;
    final appLang = Localizations.localeOf(context).languageCode;
    final state = ref.watch(lyricsTranslationProvider(appLang));
    final display = ref.watch(
      settingsProvider.select((s) => s.translation.display),
    );
    final ready = state is TranslationReady ? state : null;
    final loading = state is TranslationLoading;
    final direction = ready == null
        ? null
        : translationDirectionOf(ready.info.effective.code);
    return LyricsPulseHost(
      active: loading,
      builder: (context, pulse) => Column(
        children: [
          // The banner has its own room above the lyrics, so it never covers
          // the first lines. Its slot is always there, which keeps the view's
          // place in the tree.
          state is TranslationFailed
              ? LyricsTranslationBanner(state: state, appLang: appLang)
              : const SizedBox.shrink(),
          Expanded(
            // With a credit under them the lyrics end above it, which sits
            // clear of any bottom overlay itself; without one they keep the
            // padding so their last line scrolls clear of the overlay.
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: origin != null,
              // A new key per lyrics resets the scroll position and line
              // state.
              child: lyrics.synced
                  ? SyncedLyricsView(
                      key: ObjectKey(lyrics),
                      lyrics: lyrics,
                      translations: ready?.lines,
                      translationPending: loading,
                      display: display,
                      pulse: pulse,
                      translationDirection: direction,
                    )
                  : PlainLyricsView(
                      key: ObjectKey(lyrics),
                      lyrics: lyrics,
                      translations: ready?.lines,
                      translationPending: loading,
                      display: display,
                      pulse: pulse,
                      translationDirection: direction,
                    ),
            ),
          ),
          if (origin != null)
            LyricsCreditRow(origin: origin, synced: lyrics.synced),
        ],
      ),
    );
  }
}
