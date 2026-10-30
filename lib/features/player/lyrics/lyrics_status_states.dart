import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/database/lyrics_plugin_spec.dart' show lrclibSourceId;
import '../../../core/lyrics/online/lyrics_choice.dart';
import '../../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../core/lyrics/online/lyrics_source_names.dart';
import '../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../core/player/local_path_of.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../l10n/l10n.dart';
import 'lyrics_action_runner.dart';
import 'lyrics_provider_name.dart';
import 'lyrics_error_banner.dart';
import 'lyrics_empty_state.dart';
import 'lyrics_pulse_host.dart';
import 'translation/lyrics_translation_placeholder.dart';

/// The lyrics slot while a lookup runs: one pulsing bar and "Searching
/// {provider}…". The bar is still under reduced motion.
class LyricsSearchingView extends ConsumerWidget {
  const LyricsSearchingView({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = lyricsSourceNameText(
      context.l10n,
      ref.watch(lyricsSourceNamesProvider),
      providerId,
    );
    final style =
        theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16, height: 1.2);
    return LyricsPulseHost(
      active: true,
      builder: (context, pulse) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LyricsTranslationPlaceholder(
                style: style,
                sourceLength: 36,
                pulse: pulse,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.lyricsSearching(name),
                textAlign: TextAlign.center,
                style: style.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lyrics slot when the song has no lyrics to show: the reason, and the
/// ways to look for some. Online buttons show only for a local file with a
/// library (the lookups need both). "Turn back on" restores the stored pick
/// when the song has one, else goes to automatic. A failed lookup adds a
/// banner above, in its own slot, so the empty state keeps its place.
class LyricsNoneView extends ConsumerWidget {
  const LyricsNoneView({super.key, required this.none});

  final LyricsNone none;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // The sources that run, in the user's order. Any of them can be a plugin,
    // and the first is not special: the buttons need only one to be on.
    final enabled = ref.watch(lyricsProvidersProvider);
    final hasSource = enabled.isNotEmpty;
    final online =
        hasSource &&
        localPathOf(none.uri) != null &&
        ref.watch(libraryDatabaseProvider) != null;
    final autoOn = ref.watch(
      settingsProvider.select((s) => hasSource && s.onlineLyrics.autoAllowed),
    );
    // Turning lyrics back on keeps a stored pick: only the menu's Automatic
    // item drops it.
    final hasPick = ref.watch(
      playingLyricsSourceProvider.select((s) => s?.pin?.hasPick ?? false),
    );
    // The status does not say which source answered, so with several on the
    // texts name them all; with one, that one.
    final names = ref.watch(lyricsSourceNamesProvider);
    final name = enabled
        .map((r) => lyricsSourceNameText(l10n, names, r.id))
        .join(', ');
    // View log leads to one plugin's file: only when the one source that
    // runs is that plugin (with LRCLIB beside it the failure may be LRCLIB's).
    final onlyPlugin =
        enabled.length == 1 && enabled.first.id != lrclibSourceId;
    final reason = none.reason;

    Widget find(String label, VoidCallback onPressed) =>
        FilledButton.tonal(onPressed: onPressed, child: Text(label));
    Widget more(String label, VoidCallback onPressed) =>
        TextButton(onPressed: onPressed, child: Text(label));
    LyricsActionRunner run() => LyricsActionRunner.snapshot(context);

    final (title, actions) = switch (reason) {
      LyricsNoneReason.noLyrics || LyricsNoneReason.error => (
        null,
        [
          if (online) find(l10n.lyricsFindOnline, () => run().findOnline()),
          if (online && !autoOn && reason == LyricsNoneReason.noLyrics)
            more(l10n.lyricsFindAutomatically, () => run().enableAutomatic()),
        ],
      ),
      LyricsNoneReason.notFound => (
        l10n.lyricsNotFound(name),
        [if (online) find(l10n.lyricsSearchManually, () => run().findOnline())],
      ),
      LyricsNoneReason.off => (
        l10n.lyricsOffTitle,
        [
          find(
            l10n.lyricsOffTurnOn,
            () =>
                run().choose(hasPick ? LyricsChoice.online : LyricsChoice.auto),
          ),
        ],
      ),
      LyricsNoneReason.paused => (
        switch (none.resumeAt) {
          final at? => l10n.lyricsPausedTitle(name, at),
          null => l10n.lyricsOnlineBusy(name),
        },
        [if (online) find(l10n.lyricsRetry, () => run().retry())],
      ),
      LyricsNoneReason.instrumental => (l10n.lyricsInstrumental, <Widget>[]),
    };
    return Column(
      children: [
        reason == LyricsNoneReason.error
            ? LyricsErrorBanner(
                providerName: name,
                logProviderId: onlyPlugin ? enabled.first.id : null,
                canRetry: online,
                failure: none.failure,
              )
            : const SizedBox.shrink(),
        Expanded(
          child: LyricsEmptyState(title: title, actions: actions),
        ),
      ],
    );
  }
}
