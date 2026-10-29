import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/lyrics/online/lyrics_fetch_exception.dart';
import '../../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../core/player/local_path_of.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../l10n/l10n.dart';
import 'lyrics_credit_row.dart';
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
    final name = lyricsProviderName(
      ref.watch(lyricsProvidersProvider),
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
/// library (the lookups need both). A failed lookup adds a banner above, in
/// its own slot, so the empty state keeps its place.
class LyricsNoneView extends ConsumerWidget {
  const LyricsNoneView({super.key, required this.none});

  final LyricsNone none;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final registration = ref.watch(lyricsProvidersProvider).firstOrNull;
    final online =
        registration != null &&
        localPathOf(none.uri) != null &&
        ref.watch(libraryDatabaseProvider) != null;
    final autoOn = ref.watch(
      settingsProvider.select(
        (s) =>
            registration != null && s.onlineLyrics.autoAllowedFor(registration),
      ),
    );
    final name = registration?.displayName ?? '';
    final reason = none.reason;

    Widget find(String label, VoidCallback onPressed) =>
        FilledButton.tonal(onPressed: onPressed, child: Text(label));
    Widget more(String label, VoidCallback onPressed) =>
        TextButton(onPressed: onPressed, child: Text(label));
    LyricsActionRunner run() => LyricsActionRunner.of(context);

    final (title, actions) = switch (reason) {
      LyricsNoneReason.noLyrics || LyricsNoneReason.error => (
        null,
        [
          if (online) find(l10n.lyricsFindOnline, () => run().choose()),
          if (online && !autoOn && reason == LyricsNoneReason.noLyrics)
            more(
              l10n.lyricsFindAutomatically,
              () => run().enableAutomatic(registration),
            ),
        ],
      ),
      LyricsNoneReason.notFound => (
        l10n.lyricsNotFound(name),
        [if (online) find(l10n.lyricsSearchManually, () => run().choose())],
      ),
      // Their own texts come with the lyrics source button.
      LyricsNoneReason.off || LyricsNoneReason.paused => (null, <Widget>[]),
      LyricsNoneReason.instrumental => (l10n.lyricsInstrumental, <Widget>[]),
    };
    final origin = none.origin;
    return Column(
      children: [
        reason == LyricsNoneReason.error
            ? LyricsErrorBanner(
                providerName: name,
                canRetry: online,
                busy: none.failure == LyricsFetchKind.rateLimited,
              )
            : const SizedBox.shrink(),
        Expanded(
          child: LyricsEmptyState(title: title, actions: actions),
        ),
        if (reason == LyricsNoneReason.instrumental && origin != null)
          LyricsCreditRow(origin: origin),
      ],
    );
  }
}
