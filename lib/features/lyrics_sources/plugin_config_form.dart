import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugin_record.dart';
import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import '../../l10n/l10n.dart';
import '../../shared/lyrics_plugins/plugin_card.dart';
import 'plugin_config_choice_fields.dart';
import 'plugin_config_list_field.dart';
import 'plugin_config_map_field.dart';
import 'plugin_config_multi_select_field.dart';
import 'plugin_config_secret_field.dart';
import 'plugin_config_state_provider.dart';
import '../../shared/lyrics_plugins/config/plugin_config_text_field.dart';
import '../../shared/lyrics_plugins/config/plugin_config_toggle_field.dart';
import '../../shared/lyrics_plugins/config/plugin_config_value_messages.dart';
import 'plugin_section_title.dart';

/// "Cài đặt của plugin": the form the plugin's manifest declares. Nothing is
/// shown for a plugin with no settings. Values load once; each field saves
/// itself.
class PluginConfigForm extends ConsumerWidget {
  const PluginConfigForm({super.key, required this.record});

  final LyricsPluginRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (record.config.isEmpty) return const SizedBox.shrink();
    final state = ref.watch(
      pluginConfigStateProvider((
        installId: record.installId,
        updatedAt: record.updatedAt,
      )),
    );
    final values = state.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PluginSectionTitle(context.l10n.pluginConfigTitle),
        if (state.hasError)
          PluginCard(
            padding: const EdgeInsets.all(16),
            child: _LoadFailed(
              onRetry: () => ref.invalidate(
                pluginConfigStateProvider((
                  installId: record.installId,
                  updatedAt: record.updatedAt,
                )),
              ),
            ),
          )
        else if (values == null)
          const PluginCard(child: SizedBox(height: 56))
        else
          PluginCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in record.config) _fieldFor(field, values),
              ],
            ),
          ),
      ],
    );
  }

  Widget _fieldFor(PluginConfigField field, PluginConfigState state) {
    final id = record.installId;
    // The key holds the record's version, so an update rebuilds the field
    // from the values read for it.
    final key = ValueKey('$id/${record.updatedAt}/${field.key}');
    final value = state.stored[field.key] ?? field.defaultValue;
    switch (field.mode) {
      case PluginConfigMode.list:
        return PluginConfigListField(
          key: key,
          installId: id,
          field: field,
          initialItems: value is List ? value : const [],
        );
      case PluginConfigMode.map:
        return PluginConfigMapField(
          key: key,
          installId: id,
          field: field,
          initialEntries: value is Map
              ? {for (final e in value.entries) '${e.key}': '${e.value}'}
              : const {},
        );
      case PluginConfigMode.toggle:
        return PluginConfigToggleField(
          key: key,
          installId: id,
          field: field,
          initialValue: value is bool && value,
        );
      case PluginConfigMode.select:
        if (field.selectFormat == PluginSelectFormat.multiple) {
          return PluginConfigMultiSelectField(
            key: key,
            installId: id,
            field: field,
            initialValues: value is List
                ? [...value.whereType<String>()]
                : const [],
          );
        }
        return PluginConfigSelectField(
          key: key,
          installId: id,
          field: field,
          initialValue: value is String ? value : null,
        );
      case PluginConfigMode.input:
        if (field.inputFormat == PluginInputFormat.secret) {
          return PluginConfigSecretField(
            key: key,
            installId: id,
            field: field,
            hasSavedSecret: state.savedSecrets.contains(field.key),
            usingFallback: state.secretsUsingFallback,
          );
        }
        return PluginConfigTextField(
          key: key,
          installId: id,
          field: field,
          initialText: switch (value) {
            String() => value,
            num() => pluginNumberText(value),
            _ => '',
          },
        );
    }
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Text(l10n.pluginConfigLoadFailed)),
          TextButton(onPressed: onRetry, child: Text(l10n.pluginRetry)),
        ],
      ),
    );
  }
}
