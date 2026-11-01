import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../core/lyrics_translation/translation_service.dart';
import '../../core/lyrics_translation/translation_service_names.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/lyrics_plugins/plugin_icon.dart';
import '../../shared/translation_plugin_routes.dart';
import '../../shared/translation_service_name.dart';

/// Under the service picker: one row per installed translate plugin, which
/// opens its page (config, key, uninstall), and a row to the plugin store on
/// its Translate tab.
class TranslationPluginRows extends ConsumerWidget {
  const TranslationPluginRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plugins = ref.watch(translationPluginInfosProvider);
    final live = ref.watch(translatePluginRecordsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final record in live)
          if (TranslationServiceId.tryParse(record.installId) case final id?)
            ListTile(
              leading: PluginIcon(record: record, size: 32),
              title: Text(translationServiceName(l10n, plugins, id)),
              subtitle: Text('v${record.version}'),
              trailing: const Icon(AppIcons.chevronRight),
              onTap: () => context.go(translationPluginRoute(record.installId)),
            ),
        ListTile(
          leading: const Icon(AppIcons.download),
          title: Text(l10n.settingsTranslationGetServices),
          subtitle: Text(l10n.settingsTranslationGetServicesHint),
          trailing: const Icon(AppIcons.chevronRight),
          onTap: () => context.go(translationPluginsRoute),
        ),
      ],
    );
  }
}
