import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import '../../../../../shared/settings_routes.dart';
import '../../../../../shared/widgets/layered_modal/layered_modal_route.dart';
import '../../../now_playing/now_playing_lyrics_toggle.dart';
import '../../../now_playing/now_playing_modal_navigation.dart';
import 'lyrics_source_action_bar.dart';
import 'lyrics_source_choice_rows.dart';
import 'lyrics_source_modal_actions.dart';
import 'lyrics_source_status_line.dart';

/// Opens the "Lyrics for this song" modal at depth 0 on the root navigator.
///
/// [messenger] is the [ScaffoldMessengerState] of the opener (Now Playing),
/// so a snackbar from an action that outlives the modal shows on the screen
/// behind; when omitted, `ScaffoldMessenger.maybeOf` of [context] is
/// captured before the route is pushed.
Future<void> showLyricsSourceModal(
  BuildContext context, {
  required ScaffoldMessengerState? messenger,
}) {
  final effectiveMessenger = messenger ?? ScaffoldMessenger.maybeOf(context);
  return showLayeredModal<void>(
    context,
    semanticLabel: context.l10n.lyricsSourceModalTitle,
    builder: (_) => LyricsSourceModal(messenger: effectiveMessenger),
  );
}

/// Parent modal for the lyrics of the playing song: a header with a settings
/// button, the choice rows, a status line, the action rows and, for online
/// lyrics on screen, a bottom bar with Keep and Not this song.
///
/// It acts on the song it was opened for: when another song starts (or
/// nothing plays) the whole modal stack closes.
class LyricsSourceModal extends ConsumerStatefulWidget {
  const LyricsSourceModal({super.key, required this.messenger});

  final ScaffoldMessengerState? messenger;

  @override
  ConsumerState<LyricsSourceModal> createState() => _LyricsSourceModalState();
}

class _LyricsSourceModalState extends ConsumerState<LyricsSourceModal> {
  /// The song the modal opened for; `null` until the first build sees one.
  String? _openedUri;
  bool _closing = false;

  void _scheduleCloseStack() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      closeLayeredModalStack(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(playingLyricsSourceProvider);
    final uri = source?.status.uri;
    _openedUri ??= uri;
    if (source == null || uri != _openedUri) {
      _scheduleCloseStack();
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    // Until the source list is read (or when reading it failed) there is
    // nothing to count: the rows stay, disabled, with a neutral line.
    final loaded = ref.watch(lyricsSourcesLoadedProvider);
    final failed = ref.watch(lyricsSourcesInputProvider).hasError;
    final ready = loaded && !failed;
    final canChoose = lyricsCanChoose(ref, source);

    return LayeredModalBody(
      header: LayeredModalTopBar(
        title: l10n.lyricsSourceModalTitle,
        actions: [
          IconButton(
            tooltip: l10n.lyricsSourceModalSettings,
            icon: const Icon(AppIcons.settingsOutlined),
            onPressed: () => leaveNowPlayingTo(
              context,
              settingsFocusLocation(SettingsAnchor.playbackLyrics),
            ),
          ),
        ],
      ),
      footer: ready && canChoose
          ? LyricsSourceActionBar(source: source, messenger: widget.messenger)
          : null,
      children: [
        LyricsSourceChoiceRows(
          source: source,
          messenger: widget.messenger,
          enabled: ready && canChoose,
        ),
        if (!ready || canChoose)
          LyricsSourceStatusLine(
            source: source,
            messenger: widget.messenger,
            loaded: ready,
          ),
        LyricsSourceModalActions(
          source: source,
          messenger: widget.messenger,
          canChoose: canChoose,
          loaded: ready,
        ),
      ],
    );
  }
}
