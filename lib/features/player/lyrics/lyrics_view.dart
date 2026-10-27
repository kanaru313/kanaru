import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/playing_track_lyrics_provider.dart';
import '../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../core/player/player_service.dart';
import '../../../core/settings/settings_provider.dart';
import 'plain_lyrics_view.dart';
import 'synced_lyrics_view.dart';
import 'translation/lyrics_translation_attribution.dart';
import 'translation/lyrics_translation_banner.dart';
import 'translation/translated_line_text.dart';

/// One step of the placeholder pulse.
const _pulseDuration = Duration(milliseconds: 900);

/// Lyrics of the playing track for Now Playing: synced lyrics follow
/// playback, plain lyrics are shown as they are. Shows nothing while the
/// current track's lyrics load (the value may still be the previous
/// track's) or when it has none. With translation on, each line carries its
/// translation (or a placeholder while it comes), a banner reports a failure
/// and the credit sits at the bottom end.
class LyricsView extends ConsumerWidget {
  const LyricsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = ref.watch(
      playerServiceProvider.select((s) => s.queue.current?.uri),
    );
    final playing = ref.watch(playingTrackLyricsProvider).value;
    if (playing == null || playing.uri != uri) return const SizedBox.expand();
    final lyrics = playing.lyrics;
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
    return _PulseHost(
      active: loading,
      builder: (context, pulse) => Stack(
        fit: StackFit.expand,
        children: [
          // The banner has its own room above the lyrics, so it never covers
          // the first lines. Its slot is always there, which keeps the view's
          // place in the tree.
          Column(
            children: [
              state is TranslationFailed
                  ? LyricsTranslationBanner(state: state, appLang: appLang)
                  : const SizedBox.shrink(),
              Expanded(
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
            ],
          ),
          if (state is TranslationReady || state is TranslationSameLanguage)
            LyricsTranslationAttribution(state: state, appLang: appLang),
        ],
      ),
    );
  }
}

/// Owns the one controller that pulses every placeholder bar of the view. It
/// runs only while [active] and motion is allowed; the animation handed to
/// [builder] is `null` otherwise, which keeps the bars still.
class _PulseHost extends StatefulWidget {
  const _PulseHost({required this.active, required this.builder});

  final bool active;
  final Widget Function(BuildContext context, Animation<double>? pulse) builder;

  @override
  State<_PulseHost> createState() => _PulseHostState();
}

class _PulseHostState extends State<_PulseHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pulseDuration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.35,
    end: 1,
  ).animate(_curve);

  bool get _pulsing =>
      widget.active && !MediaQuery.disableAnimationsOf(context);

  void _sync() {
    if (_pulsing) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_PulseHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _pulsing ? _opacity : null);
}

/// Whether Now Playing should make room for lyrics: the playing track's
/// lyrics, or while the next track's load, the previous ones (so the layout
/// does not jump on every track change). Only watched while Now Playing is
/// shown.
final nowPlayingHasLyricsProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(playingTrackLyricsProvider).value != null,
);
