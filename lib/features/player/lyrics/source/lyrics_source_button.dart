import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics/lyrics.dart' show LyricsSource;
import '../../../../core/lyrics/online/playing_lyrics_status.dart'
    show LyricsFound;
import '../../../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../../../core/lyrics/online/lyrics_source_names.dart';
import '../../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../../core/lyrics/playing_local_lyrics_provider.dart';
import '../../../../l10n/l10n.dart';
import '../lyrics_action_runner.dart';
import '../translation/lyrics_translation_pill.dart'
    show lyricsTranslationMinLabelWidth;
import 'lyrics_source_labels.dart';
import 'lyrics_source_menu.dart';
import 'lyrics_source_menu_focus.dart';
import 'lyrics_source_trigger.dart';

/// Header button that names where the playing song's lyrics come from and
/// opens the menu to change it. With room for a label it is a pill, like the
/// translate button's; with less (or in the narrow layout) it is the round
/// icon with the label as its tooltip. Only this widget watches the lyrics
/// source, so a change rebuilds the button and nothing around it.
///
/// The menu works on a snapshot of the song and its source taken when it
/// opens (see [lyricsSourceMenuItems]) and closes when the playing song
/// changes. The button hands the screen a callback that opens the menu
/// ([menuOpener], for the `L` key) while it is in the tree.
class LyricsSourceButton extends ConsumerStatefulWidget {
  const LyricsSourceButton({
    super.key,
    this.onMenuChanged,
    this.menuOpener,
    this.maxLabelWidth,
  });

  /// Called with `true` when the menu opens and `false` when it closes, also
  /// when the button leaves the tree with the menu open (as the translate
  /// button's).
  final ValueChanged<bool>? onMenuChanged;

  /// Receives the "open the menu" callback while the button is mounted.
  final ValueNotifier<bool Function()?>? menuOpener;

  /// Room for the pill's label; `null` or less than
  /// [lyricsTranslationMinLabelWidth] keeps the round icon.
  final double? maxLabelWidth;

  @override
  ConsumerState<LyricsSourceButton> createState() => _LyricsSourceButtonState();
}

class _LyricsSourceButtonState extends ConsumerState<LyricsSourceButton> {
  final _menu = MenuController();
  final _focus = LyricsSourceMenuFocus();

  /// What the open menu acts on; taken when it opens.
  LyricsActionRunner? _runner;

  /// Where the song's own lyrics come from, as of the moment the menu opened.
  LyricsSource? _ownSource;
  bool _open = false;

  /// Whether the build below put the menu anchor in the tree; opening a
  /// menu without one throws.
  bool _anchored = false;

  @override
  void didUpdateWidget(LyricsSourceButton old) {
    super.didUpdateWidget(old);
    if (old.menuOpener == widget.menuOpener) return;
    final previous = old.menuOpener;
    // After the frame, so a listener of the notifier never runs while the
    // tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (previous?.value == _openFromKey) previous?.value = null;
    });
  }

  /// Hands `L` the opener while there is a song to act on, and takes it
  /// back otherwise. Runs after the frame: the notifier is never written
  /// during a build, so a listener can safely rebuild.
  void _syncOpener() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final opener = widget.menuOpener;
    if (!mounted || opener == null) return;
    if (!_anchored && opener.value == _openFromKey) {
      opener.value = null;
    } else if (_anchored && opener.value != _openFromKey) {
      opener.value = _openFromKey;
    }
  });

  @override
  void dispose() {
    final opener = widget.menuOpener;
    if (opener != null && opener.value == _openFromKey) opener.value = null;
    _setOpen(false);
    _focus.dispose();
    super.dispose();
  }

  void _setOpen(bool open) {
    if (_open == open) return;
    _open = open;
    widget.onMenuChanged?.call(open);
  }

  /// Opens or closes the menu; `false` when it could not open (no anchor,
  /// or no song to act on).
  bool _toggle() {
    if (_menu.isOpen) {
      _menu.close();
      return true;
    }
    final source = ref.read(playingLyricsSourceProvider);
    if (!_anchored || source == null) return false;
    final runner = LyricsActionRunner.snapshot(context, source: source);
    if (runner.target == null) return false;
    // The song's own lyrics are kept only when they were read for this song:
    // the provider holds the previous song's value while the next one loads.
    final own = ref.read(playingLocalLyricsProvider).value;
    setState(() {
      _runner = runner;
      _ownSource = own != null && own.uri == source.status.uri
          ? own.lyrics.source
          : null;
    });
    _menu.open();
    return true;
  }

  /// The `L` key: opens the menu (which focuses its first item, so the arrow
  /// keys work at once). `false` when nothing opened.
  bool _openFromKey() => !_menu.isOpen && _toggle();

  /// Puts the focus into the menu however it opened, so Escape closes the
  /// menu and not the screen behind it.
  void _focusMenu() => _focus.focusAfterFrame(
    isAlive: () => mounted,
    isOpen: () => _menu.isOpen,
  );

  void _closeLater() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _menu.isOpen) _menu.close();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final source = ref.watch(playingLyricsSourceProvider);
    final providers = ref.watch(lyricsProvidersProvider);
    final names = ref.watch(lyricsSourceNamesProvider);
    _anchored = source != null;
    // Without a source there is nothing to open: `L` must see no callback.
    if (widget.menuOpener != null) _syncOpener();
    if (source == null) {
      // Nothing plays: the menu has nothing to act on.
      if (_open) _closeLater();
      return const SizedBox.shrink();
    }
    final runner = _runner;
    if (_open && runner?.source?.status.uri != source.status.uri) {
      // The menu would act on the previous song.
      _closeLater();
    }
    final label = lyricsSourceLabel(l10n, source, names);
    final muted = lyricsSourceMuted(source);
    final room = widget.maxLabelWidth ?? 0;

    return MenuAnchor(
      controller: _menu,
      // Air between the button and the menu.
      alignmentOffset: const Offset(0, 8),
      onOpen: () {
        _setOpen(true);
        _focusMenu();
      },
      onClose: () => _setOpen(false),
      menuChildren: runner == null
          ? const []
          : lyricsSourceMenuItems(
              context,
              runner,
              providers,
              names,
              ownSource: _ownSource,
              firstItemFocus: _focus.firstItem,
              headerFocus: _focus.header,
            ),
      builder: (context, controller, _) => LyricsSourceTrigger(
        label: label,
        title: lyricsSourceMenuTitle(l10n, source, names),
        found: source.status is LyricsFound,
        muted: muted,
        room: room,
        onPressed: _toggle,
      ),
    );
  }
}
