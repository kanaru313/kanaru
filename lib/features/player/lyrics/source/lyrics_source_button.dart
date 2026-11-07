import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics/online/lyrics_source_names.dart';
import '../../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/icons/app_icons.dart';
import '../../../../shared/lyrics_picker/lyrics_source_name_text.dart';
import '../../../../shared/lyrics_plugins/plugin_icon.dart';
import '../../now_playing/now_playing_lyrics_toggle.dart';
import '../../playback_controls.dart';
import 'lyrics_source_labels.dart';
import 'modal/lyrics_source_modal.dart';

/// Round header button for the lyrics of the playing song. Press (or `L`)
/// opens the "Lyrics for this song" modal; a secondary tap turns lyrics off,
/// or back on to what they were.
///
/// The icon says what shows: the lyrics icon in the primary colour for the
/// song's own lyrics, the plugin's icon on a raised background for online
/// lyrics, a struck-through icon when off, and a dim icon when there are none.
/// A ring turns around it while lyrics are being looked up online. Only this
/// widget watches the lyrics source, so a change rebuilds the button and
/// nothing around it.
///
/// [onModalChanged] is called with `true` while the modal stack is open and
/// `false` when it closes (also when the button leaves the tree with it open).
/// [modalOpener] receives the "open the modal" callback, for the `L` key,
/// while the button is mounted and there is a song.
class LyricsSourceButton extends ConsumerStatefulWidget {
  const LyricsSourceButton({super.key, this.onModalChanged, this.modalOpener});

  final ValueChanged<bool>? onModalChanged;
  final ValueNotifier<bool Function()?>? modalOpener;

  @override
  ConsumerState<LyricsSourceButton> createState() => _LyricsSourceButtonState();
}

class _LyricsSourceButtonState extends ConsumerState<LyricsSourceButton> {
  bool _open = false;
  bool _usable = false;

  void _setOpen(bool open) {
    if (_open == open) return;
    _open = open;
    widget.onModalChanged?.call(open);
  }

  @override
  void didUpdateWidget(LyricsSourceButton old) {
    super.didUpdateWidget(old);
    if (old.modalOpener == widget.modalOpener) return;
    final previous = old.modalOpener;
    // After the frame, so a listener of the notifier never runs while the
    // tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (previous?.value == _openModal) previous?.value = null;
    });
  }

  /// Hands `L` the opener while there is a song, and takes it back otherwise.
  void _syncOpener() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final opener = widget.modalOpener;
    if (!mounted || opener == null) return;
    if (!_usable && opener.value == _openModal) {
      opener.value = null;
    } else if (_usable && opener.value != _openModal) {
      opener.value = _openModal;
    }
  });

  @override
  void dispose() {
    final opener = widget.modalOpener;
    if (opener != null && opener.value == _openModal) opener.value = null;
    _setOpen(false);
    super.dispose();
  }

  bool _openModal() {
    if (_open || !_usable) return false;
    unawaited(_runModal());
    return true;
  }

  Future<void> _runModal() async {
    _setOpen(true);
    // Taken before the route is pushed, for snackbars of actions that outlive
    // the modal.
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await showLyricsSourceModal(context, messenger: messenger);
    } finally {
      // The modal route puts focus back where it was when it closes.
      if (mounted) _setOpen(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(playingLyricsSourceProvider);
    _usable = source != null;
    if (widget.modalOpener != null) _syncOpener();
    // Nothing plays: nothing to open, and `L` sees no callback.
    if (source == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final names = ref.watch(lyricsSourceNamesProvider);
    final records = ref.watch(lyricsPluginRecordsProvider);
    final scheme = Theme.of(context).colorScheme;
    final status = source.status;
    final tooltip =
        '${lyricsSourceTooltipTitle(l10n, source, names)}'
        '\n${l10n.lyricsSourceButtonHint}';
    // Only a lookup turns the ring: reading the song's own lyrics is over in a
    // moment, and a ring for it would flicker at every track change.
    final looking = status is LyricsSearching;
    final canChoose = lyricsCanChoose(ref, source);

    Widget? online;
    var icon = AppIcons.lyrics;
    var color = scheme.onSurfaceVariant.withValues(alpha: 0.6);
    switch (status) {
      case LyricsFound(origin: null):
        color = scheme.primary;
      case LyricsFound(:final origin?):
        final name = lyricsSourceNameText(l10n, names, origin.providerId);
        final record = records
            .where((r) => r.installId == origin.providerId)
            .firstOrNull;
        online = PluginIcon(record: record, size: 20, letterOf: name);
      case LyricsNone(reason: LyricsNoneReason.off):
        icon = AppIcons.lyricsOff;
        color = scheme.onSurfaceVariant;
      default:
        break;
    }

    final button = Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: online ?? Icon(icon),
          iconSize: playerIconSize,
          style: IconButton.styleFrom(
            // A 20 px plugin logo would leave a smaller circle than the 28 px
            // icons around it: keep the round buttons' size either way.
            minimumSize: const Size.square(playerIconSize + 16),
            foregroundColor: color,
            backgroundColor: online == null
                ? null
                : scheme.surfaceContainerHighest,
          ),
          tooltip: tooltip,
          onPressed: _openModal,
        ),
        if (looking)
          const Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.all(5),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
    return GestureDetector(
      onSecondaryTap: canChoose
          ? () => quickToggleLyrics(
              context,
              ref,
              messenger: ScaffoldMessenger.maybeOf(context),
            )
          : null,
      child: button,
    );
  }
}
