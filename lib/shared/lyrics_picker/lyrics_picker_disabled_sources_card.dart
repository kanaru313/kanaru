import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../core/lyrics/online/lyrics_search_controller.dart';
import '../../core/lyrics/online/lyrics_source_names.dart';
import '../../l10n/l10n.dart';
import 'lyrics_source_name_text.dart';

/// A turned-off lyrics source as the card and the sources modal name it: its
/// display name and the hosts a search would contact.
typedef LyricsPickerOffSource = ({String id, String name, String hosts});

/// The off sources among [off] that the search of [state] has not asked yet.
List<LyricsPickerOffSource> unsearchedOffSources(
  AppLocalizations l10n,
  Map<String, LyricsSourceName> names,
  List<LyricsProviderRegistration> off,
  LyricsSearchState state,
) => [
  for (final r in off)
    if (!state.onDemand.contains(r.id))
      (
        id: r.id,
        name: lyricsSourceNameText(l10n, names, r.id),
        hosts: r.hosts.join(', '),
      ),
];

/// Offers the off sources that were not searched yet. It names each source
/// with its hosts; pressing the button is the consent for that one search
/// (nothing is stored, no setting changes). With [noneOn] no source is on and
/// the button reads "Search in N disabled sources"; otherwise the card
/// sits at the end of the results as "Didn't find the right lyrics? N sources
/// are off".
class LyricsPickerDisabledSourcesCard extends StatelessWidget {
  const LyricsPickerDisabledSourcesCard({
    super.key,
    required this.sources,
    required this.onSearch,
    this.noneOn = false,
  });

  final List<LyricsPickerOffSource> sources;

  /// `null` while there is no query to search for (the button is off).
  final VoidCallback? onSearch;
  final bool noneOn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!noneOn)
                Text(
                  l10n.lyricsPickerMoreOff(sources.length),
                  style: theme.textTheme.titleSmall,
                ),
              for (final s in sources)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.lyricsPickerSearchSourceHosts(s.name, s.hosts),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: onSearch,
                  child: Text(
                    noneOn
                        ? l10n.lyricsPickerSearchDisabled(sources.length)
                        : l10n.lyricsPickerSearch,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
