import 'package:material_ui/material_ui.dart';

import '../../core/database/lyrics_plugin_spec.dart' show PluginKind;
import '../../l10n/l10n.dart';
import 'plugin_store_filter_labels.dart';

/// A small label naming a plugin's kind, shown on rows while the store lists
/// more than one kind.
class PluginStoreKindTag extends StatelessWidget {
  const PluginStoreKindTag({super.key, required this.kind});

  final PluginKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          pluginKindLabel(context.l10n, kind),
          style: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}
