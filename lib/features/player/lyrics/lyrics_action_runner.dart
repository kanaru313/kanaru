import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../../core/lyrics/online/lyrics_target.dart';
import '../../../core/lyrics/online/online_lyrics_actions.dart';
import '../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../core/player/player_service.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/lyrics_picker/lyrics_picker.dart';
import '../../../shared/online_lyrics_notice_dialog.dart';
import '../../../shared/widgets/app_snack_bar.dart';

final _log = Logger('lyrics_view');

/// What the buttons and menus of the lyrics slot do for one song.
///
/// It takes everything it needs once, when it is built (the container, the
/// root navigator, the messenger, the song and its lyrics source), so a track
/// change or a closed menu during a dialog cannot redirect the action: it
/// always acts on the song the user saw.
class LyricsActionRunner {
  LyricsActionRunner._(
    this.container,
    this.navigator,
    this.messenger,
    this.target,
    this.source,
  );

  /// Captures the playing song now. [target] defaults to the library's view
  /// of the playing song, else the queue track's; [source] is the lyrics
  /// source the user saw (`null` when the caller has none).
  factory LyricsActionRunner.snapshot(
    BuildContext context, {
    LyricsTarget? target,
    LyricsSourceResolution? source,
  }) {
    final container = ProviderScope.containerOf(context);
    return LyricsActionRunner._(
      container,
      Navigator.of(context, rootNavigator: true),
      ScaffoldMessenger.maybeOf(context),
      target ?? _playingTarget(container),
      source,
    );
  }

  final ProviderContainer container;
  final NavigatorState navigator;
  final ScaffoldMessengerState? messenger;

  /// The song this runner acts on; `null` when nothing played.
  final LyricsTarget? target;

  /// The lyrics source of [target] when the runner was built.
  final LyricsSourceResolution? source;

  OnlineLyricsActions get _actions =>
      container.read(onlineLyricsActionsProvider);

  /// The online record on screen, which Save lyrics writes; `null` for the
  /// song's own lyrics or no lyrics.
  OnlineLyricsOrigin? get origin {
    final status = source?.status;
    return status is LyricsFound ? status.origin : null;
  }

  static LyricsTarget? _playingTarget(ProviderContainer container) {
    final fromLibrary = container.read(lyricsTargetProvider).value;
    if (fromLibrary != null) return fromLibrary;
    final track = container.read(playerServiceProvider).queue.current;
    return track == null ? null : LyricsTarget.fromTrack(track);
  }

  Future<void> _run(Future<void> Function(LyricsTarget target) action) async {
    final target = this.target;
    if (target == null) return;
    await guarded(() => action(target));
  }

  /// Runs [body]; an error is logged (its type only) and told with a generic
  /// snackbar, so a button never fails silently.
  Future<void> guarded(Future<void> Function() body) async {
    try {
      await body();
    } on Object catch (e) {
      // The type only: a message or stack may name files.
      _log.warning('lyrics action failed: ${e.runtimeType}');
      if (!navigator.mounted) return;
      messenger
        ?..clearSnackBars()
        ..showSnackBar(
          appSnackBar(
            kind: AppSnackBarKind.error,
            title: navigator.context.l10n.libraryUnexpectedError,
          ),
        );
    }
  }

  /// Opens the Choose lyrics dialog, after the consent notice.
  Future<void> choose() => _run(
    (target) => showLyricsPicker(
      navigator: navigator,
      container: container,
      target: target,
      messenger: messenger,
    ),
  );

  /// Asks for consent to look lyrics up automatically and turns it on.
  Future<void> enableAutomatic(LyricsProviderRegistration registration) =>
      guarded(
        () => confirmOnlineLyricsNotice(
          navigator,
          container,
          registration,
          auto: true,
        ),
      );

  Future<void> retry() => _run(_actions.retry);
}
