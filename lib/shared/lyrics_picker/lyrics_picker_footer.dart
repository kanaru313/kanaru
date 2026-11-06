import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../l10n/l10n.dart';

/// The line under the results naming the hosts a search contacts: those of
/// [registrations], the sources the search asked (the on sources and the off
/// ones searched on request), never an off source that was not searched.
class LyricsPickerFooter extends StatelessWidget {
  const LyricsPickerFooter({super.key, required this.registrations});

  final List<LyricsProviderRegistration> registrations;

  @override
  Widget build(BuildContext context) {
    final hosts = registrations.expand((r) => r.hosts).toSet().join(', ');
    final l10n = context.l10n;
    // With no source asked yet there are no hosts to name.
    return Text(
      hosts.isEmpty
          ? l10n.lyricsPickerFooterNoHosts
          : l10n.lyricsPickerFooter(hosts),
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
