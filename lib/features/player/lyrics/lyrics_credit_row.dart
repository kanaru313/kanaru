import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../l10n/l10n.dart';

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
