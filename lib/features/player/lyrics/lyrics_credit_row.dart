import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../../core/lyrics/online/lyrics_target.dart';
import '../../../core/lyrics/online/online_lyrics_actions.dart';
import '../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../core/player/player_service.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/lyrics_picker/lyrics_picker.dart';
import '../../../shared/online_lyrics_notice_dialog.dart';
import '../../../shared/widgets/app_snack_bar.dart';

final _log = Logger('lyrics_view');

/// Name of the service [providerId]; the id when it is not registered.
String lyricsProviderName(
  List<LyricsProviderRegistration> registrations,
  String providerId,
) {
  for (final r in registrations) {
    if (r.id == providerId) return r.displayName;
  }
  return providerId;
}

/// What the buttons of the lyrics slot do for the playing song. It takes the
/// container, root navigator and messenger when a button is pressed, so a
/// track change or a closed menu during a dialog cannot break the action.
class LyricsActionRunner {
  LyricsActionRunner._(this._container, this._navigator, this._messenger);

  factory LyricsActionRunner.of(BuildContext context) => LyricsActionRunner._(
    ProviderScope.containerOf(context),
    Navigator.of(context, rootNavigator: true),
    ScaffoldMessenger.maybeOf(context),
  );

  final ProviderContainer _container;
  final NavigatorState _navigator;
  final ScaffoldMessengerState? _messenger;
  OnlineLyricsActions get _actions =>
      _container.read(onlineLyricsActionsProvider);

  /// The playing song: the library's view of it, else the queue track's.
  LyricsTarget? get _target {
    final fromLibrary = _container.read(lyricsTargetProvider).value;
    if (fromLibrary != null) return fromLibrary;
    final track = _container.read(playerServiceProvider).queue.current;
    return track == null ? null : LyricsTarget.fromTrack(track);
  }

  Future<void> _run(Future<void> Function(LyricsTarget target) action) async {
    final target = _target;
    if (target == null) return;
    await _guard(() => action(target));
  }

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } on Object catch (e, s) {
      _log.warning('lyrics action failed: ${e.runtimeType}', e, s);
      if (!_navigator.mounted) return;
      _messenger
        ?..clearSnackBars()
        ..showSnackBar(
          appSnackBar(
            kind: AppSnackBarKind.error,
            title: _navigator.context.l10n.libraryUnexpectedError,
          ),
        );
    }
  }

  /// Opens the Choose lyrics dialog, after the consent notice.
  Future<void> choose() => _run(
    (target) => showLyricsPicker(
      navigator: _navigator,
      container: _container,
      target: target,
      messenger: _messenger,
    ),
  );

  /// Asks for consent to look lyrics up automatically and turns it on.
  Future<void> enableAutomatic(LyricsProviderRegistration registration) =>
      _guard(
        () => confirmOnlineLyricsNotice(
          _navigator,
          _container,
          registration,
          auto: true,
        ),
      );

  Future<void> retry() => _run(_actions.retry);
}

/// "Lyrics from LRCLIB" (+ " · not synced") at the bottom end of the lyrics.
class LyricsCreditRow extends ConsumerWidget {
  const LyricsCreditRow({super.key, required this.origin, this.synced = true});

  final OnlineLyricsOrigin origin;

  final bool synced; // plain lyrics say so in the credit

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final name = lyricsProviderName(
      ref.watch(lyricsProvidersProvider),
      origin.providerId,
    );
    final label = synced
        ? l10n.lyricsCreditFrom(name)
        : '${l10n.lyricsCreditFrom(name)} · ${l10n.lyricsCreditNotSynced}';
    final color = theme.colorScheme.onSurfaceVariant;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        // Sit above the Lyrics only strip, which arrives as bottom padding.
        padding: EdgeInsetsDirectional.only(
          end: 12,
          bottom: 8 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}
