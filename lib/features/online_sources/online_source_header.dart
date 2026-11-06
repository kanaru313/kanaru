import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/sources/source_plugin_records.dart';
import '../../l10n/l10n.dart';
import '../../shared/lyrics_plugins/plugin_icon.dart';
import '../../shared/online_routes.dart';

/// The icon button at the right end of the Online header: the plugin's own
/// icon, opening its page (settings, info, log, uninstall).
class OnlineSourceButton extends StatelessWidget {
  const OnlineSourceButton({super.key, required this.record});

  final LyricsPluginRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The tooltip names the button for the mouse; the label (with the
    // plugin's name) names it for screen readers.
    return Tooltip(
      message: l10n.onlineSourceTooltip,
      child: Semantics(
        button: true,
        label: l10n.onlineSourceSemantics(record.name),
        excludeSemantics: true,
        child: IconButton(
          icon: PluginIcon(record: record, size: 32),
          onPressed: () =>
              context.go(onlineSourcePluginRoute(record.installId)),
        ),
      ),
    );
  }
}
