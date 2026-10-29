import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../shared/translation_notice_dialog.dart';
import '../player_shortcuts.dart' show isTextInputFocused;
import '../queue/queue_panel.dart';
import '../queue/queue_sheet_host.dart';
import '../cover_tint_background.dart';
import 'now_playing_auto_hide.dart';
import 'now_playing_open_provider.dart';
import 'now_playing_title_bar.dart';
import 'now_playing_tabs.dart';
import 'now_playing_view_mode.dart';
import 'now_playing_wide_layout.dart';

/// Window width below which Now Playing becomes one column with tabs.
const _wideBreakpoint = 720.0;

/// The full-window Now Playing page. Its own [Scaffold], a sibling of the
/// shell's rather than nested in it, so snack bars show on top of it.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({
    super.key,
    this.titleBar,
    this.lyrics,
    this.hasLyrics,
  });

  /// See `NowPlayingOverlay.titleBar`.
  final NowPlayingTitleBar? titleBar;

  /// Lyrics view, always shown: a track without lyrics shows the empty state
  /// in it. The wide layout shows it in a tab next to the queue; the narrow
  /// layout as a page right of the track. Empty when `null`.
  final Widget? lyrics;

  /// Whether the playing track has lyrics; translation needs them. Defaults
  /// to whether [lyrics] is set.
  final bool? hasLyrics;

  bool get _hasLyrics => hasLyrics ?? lyrics != null;

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  final _focus = FocusNode(debugLabel: 'Now Playing');
  final _chrome = AutoHideController();

  /// Whether the volume popup or the sleep timer menu is open. They float
  /// outside the header, so the chrome stays shown meanwhile.
  final _floatingOpen = ValueNotifier<bool>(false);

  void _pinForFloating() =>
      _floatingOpen.value ? _chrome.pin() : _chrome.unpin();

  @override
  void initState() {
    super.initState();
    _floatingOpen.addListener(_pinForFloating);
    // `autofocus` alone loses to whatever the shell still has focused, which
    // is only released once this frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _chrome.poke();
  }

  @override
  void dispose() {
    _floatingOpen
      ..removeListener(_pinForFloating)
      ..dispose();
    _focus.dispose();
    _chrome.dispose();
    super.dispose();
  }

  void _choose(NowPlayingViewMode mode) =>
      ref.read(nowPlayingViewModeProvider.notifier).choose(mode);

  /// `L` cycles the view mode (wide layout only) and `T` turns the lyrics
  /// translation on or off (both layouts, not in Cover only). Each works only
  /// where the key is not meant for something else: with no modifier, no text
  /// field and no open popup or menu (a menu is no route, so its keys bubble
  /// up to here).
  KeyEventResult _onKey(KeyEvent event, bool wide) {
    _chrome.poke();
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isL = key == LogicalKeyboardKey.keyL;
    if (!(isL && wide) && key != LogicalKeyboardKey.keyT) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed ||
        _floatingOpen.value ||
        isTextInputFocused()) {
      return KeyEventResult.ignored;
    }
    if (!isL) {
      // Cover only shows no lyrics, so there is nothing to translate.
      if (wide &&
          ref.read(nowPlayingViewModeProvider) ==
              NowPlayingViewMode.coverOnly) {
        return KeyEventResult.ignored;
      }
      _toggleTranslation();
      return KeyEventResult.handled;
    }
    _choose(nextViewMode(ref.read(nowPlayingViewModeProvider)));
    return KeyEventResult.handled;
  }

  /// Turning translation off always works; turning it on needs lyrics and,
  /// the first time for a service, the network notice.
  void _toggleTranslation() {
    final prefs = ref.read(settingsProvider).translation;
    if (prefs.show && !prefs.needsNotice) {
      ref.read(settingsProvider.notifier).toggleLyricsTranslation();
    } else if (widget._hasLyrics) {
      unawaited(enableTranslationWithNotice(context, ref, prefs.service));
    }
  }

  void _close() => ref.read(nowPlayingOpenProvider.notifier).close();

  NowPlayingDragExclusion get _exclude =>
      widget.titleBar?.excludeFromDrag ?? noDragExclusion;

  Widget _wrapHeader(Widget header) =>
      widget.titleBar?.wrapHeader(header) ?? header;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final mode = ref.watch(nowPlayingViewModeProvider);
    final lyrics = widget.lyrics ?? const SizedBox.expand();
    // Esc is mapped to DismissIntent by the app; nothing handles it unless a
    // route does, so this is what closes the screen.
    return FocusScope(
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _close();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focus,
          // Any key brings the hidden header back, so focus is
          // never left on a button nobody can see.
          onKeyEvent: (_, event) => _onKey(event, wide),
          // Nothing here opens the queue sheet; the host stays so the mouse
          // back button closes Now Playing.
          child: QueueSheetHost(
            onMouseBack: _close,
            onOpenChanged: (open) => open ? _chrome.pin() : _chrome.unpin(),
            // The background is the gradient's, which is always opaque.
            child: CoverTintBackground(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: wide
                    ? NowPlayingWideLayout(
                        chrome: _chrome,
                        floatingOpen: _floatingOpen,
                        onClose: _close,
                        titleBar: widget.titleBar,
                        lyrics: lyrics,
                        mode: mode,
                        hasLyrics: widget._hasLyrics,
                        onChoose: _choose,
                      )
                    : NowPlayingTabs(
                        wrapHeader: _wrapHeader,
                        excludeFromDrag: _exclude,
                        queuePage: const QueuePanel(),
                        lyricsPage: lyrics,
                        onClose: _close,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
