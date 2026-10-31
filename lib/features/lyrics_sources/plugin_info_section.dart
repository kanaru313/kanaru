import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugin_record.dart';
import '../../l10n/l10n.dart';
import 'plugin_section_title.dart';
import 'plugin_source_text.dart';

/// "Thông tin" of an installed plugin: where it came from, the hosts it may
/// connect to, when it was installed and its description. The install id is
/// internal and not shown.
class PluginInfoSection extends StatelessWidget {
  const PluginInfoSection({super.key, required this.record});

  final LyricsPluginRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dates = MaterialLocalizations.of(context);
    String day(int ms) =>
        dates.formatShortDate(DateTime.fromMillisecondsSinceEpoch(ms));
    final installed = day(record.installedAt);
    final updated = day(record.updatedAt);
    final repoUrl = record.repoUrl;
    final description = record.description?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PluginSectionTitle(l10n.pluginInfoTitle),
        _Item(
          label: l10n.pluginInfoSource,
          lines: [
            pluginSourceText(l10n, record),
            if (repoUrl != null && repoUrl.isNotEmpty) repoUrl,
          ],
        ),
        _Item(label: l10n.pluginInfoHosts, lines: record.hosts),
        _Item(
          label: l10n.pluginInfoInstalled,
          lines: [
            updated == installed
                ? installed
                : l10n.pluginInfoInstalledUpdated(installed, updated),
          ],
        ),
        if (description.isNotEmpty)
          _Item(label: l10n.pluginInfoDescription, lines: [description]),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.label, required this.lines});

  final String label;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final line in lines) SelectableText(line),
        ],
      ),
    );
  }
}
