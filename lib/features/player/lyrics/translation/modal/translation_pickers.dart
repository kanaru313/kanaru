import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/database/lyrics_plugin_spec.dart';
import '../../../../../core/lyrics/plugins/lyrics_plugin_record.dart';
import '../../../../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../../core/lyrics_translation/translation_language.dart';
import '../../../../../core/lyrics_translation/translation_scope.dart';
import '../../../../../core/lyrics_translation/translation_service.dart';
import '../../../../../core/lyrics_translation/translation_service_choices.dart';
import '../../../../../core/lyrics_translation/translation_service_names.dart';
import '../../../../../core/player/player_service.dart';
import '../../../../../core/settings/settings_provider.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import '../../../../../shared/lyrics_plugins/plugin_icon.dart';
import '../../../../../shared/translation_language_name.dart';
import '../../../../../shared/translation_notice_dialog.dart';
import '../../../../../shared/translation_service_name.dart';
import '../../../../../shared/widgets/app_snack_bar.dart';
import '../../../../../shared/widgets/marquee_text.dart';
import '../../../../../shared/widgets/selection_picker.dart';
import 'translation_ai_badge.dart';
import 'translation_modal_navigation.dart';
import 'translation_scope_header.dart';
import 'translation_service_pick.dart';

final _log = Logger('translation');

/// Sentinel value for the `"Default (<language>)"` entry in the target picker.
const String _defaultLanguage = '';

/// Pause before an overflowing footer row label starts scrolling.
const Duration _footerMarqueeDelay = Duration(milliseconds: 300);

/// Opens the child modal that picks the per-song target language.
///
/// Offers `"Default (<default language>)"` followed by every entry in
/// [translationLanguages], so the search box is always shown. Choosing an item
/// writes [LyricsTranslationController.setSongTarget] (`null` for Default) and
/// returns to the parent modal.
Future<void> openTargetPicker(
  BuildContext context,
  WidgetRef ref, {
  required TranslationTargetInfo info,
  required String appLang,
}) async {
  final l10n = context.l10n;
  final controller = ref.read(lyricsTranslationProvider(appLang).notifier);
  // Taken before any await: the modal may be gone when the write fails.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failedText = l10n.lyricsTranslationTargetSaveFailed;
  final items = <SelectionPickerItem<String>>[
    SelectionPickerItem(
      value: _defaultLanguage,
      name: l10n.lyricsTranslationTargetDefault(
        translationLanguageName(l10n, info.defaultTarget),
      ),
    ),
    for (final language in translationLanguages)
      SelectionPickerItem(
        value: language.code,
        name: translationLanguageName(l10n, language),
      ),
  ];
  final picked = await showSelectionPicker<String>(
    context,
    title: l10n.lyricsTranslationModalTargetTitle,
    items: items,
    selected: info.songOverride ?? _defaultLanguage,
  );
  if (picked == null) return;
  try {
    await controller.setSongTarget(picked == _defaultLanguage ? null : picked);
  } on Object catch (error) {
    _log.warning(
      'saving the song translation target failed: ${error.runtimeType}',
    );
    messenger?.showSnackBar(
      appSnackBar(kind: AppSnackBarKind.error, title: failedText),
    );
  }
}

/// Opens the child modal that picks the translation service plugin.
///
/// Lists the live translate plugins with scope segments on top (this song
/// only, the current queue, or the default for every song), a footer row that
/// opens the plugin store and a cache-first hint. The check mark is on the
/// song's own service ([info]'s choice), or on the default when [info] is
/// null. The segment is "this song" on every open, except when that is locked
/// (translation off, or no song with lyrics): then it is "all songs".
/// Choosing a plugin first asks the network notice in a dialog above the
/// picker: Cancel keeps the picker and the chosen segment open; Continue
/// closes it and [applyServicePick] writes the choice without forcing a
/// retranslate.
Future<void> openServicePicker(
  BuildContext context,
  WidgetRef ref, {
  required TranslationTargetInfo? info,
}) async {
  final choices = ref.read(translationServiceChoicesProvider);
  if (!choices.ready) return;
  final l10n = context.l10n;
  final plugins = ref.read(translationPluginInfosProvider);
  final records = ref.read(lyricsPluginRecordsProvider);
  final hash = info?.hash;
  final locked = <TranslationScope, String>{
    if (!ref.read(settingsProvider).translation.show)
      TranslationScope.song: l10n.lyricsTranslationScopeSongLockedOff
    else if (hash == null)
      TranslationScope.song: l10n.lyricsTranslationScopeSongLockedNoSong,
    if (!ref.read(settingsProvider).translation.show)
      TranslationScope.queue: l10n.lyricsTranslationScopeQueueLockedOff
    else if (ref.read(playerServiceProvider).queue.isEmpty)
      TranslationScope.queue: l10n.lyricsTranslationScopeQueueLockedEmpty,
  };
  final scope = ValueNotifier(
    locked.containsKey(TranslationScope.song)
        ? TranslationScope.all
        : TranslationScope.song,
  );
  final caption = allScopeCaption(ref);
  final items = <SelectionPickerItem<TranslationServiceId>>[
    for (final service in choices.services)
      SelectionPickerItem(
        value: service,
        name: translationServiceName(l10n, plugins, service),
        leading: PluginIcon(
          record: _recordFor(records, service.value),
          size: 24,
        ),
        badge:
            _recordFor(records, service.value)?.kind == PluginKind.aiTranslate
            ? const TranslationAiBadge()
            : null,
      ),
  ];
  final picked = await showSelectionPicker<TranslationServiceId>(
    context,
    title: l10n.lyricsTranslationModalServiceTitle,
    items: items,
    selected: info?.choice?.service ?? choices.selected,
    header: ValueListenableBuilder<TranslationScope>(
      valueListenable: scope,
      builder: (_, selected, _) => TranslationScopeHeader(
        scopes: const [
          TranslationScope.song,
          TranslationScope.queue,
          TranslationScope.all,
        ],
        selected: selected,
        locked: locked,
        precedence: caption.precedence,
        customCount: caption.songs,
        queueHasChoice: caption.queue,
        onChanged: (s) => scope.value = s,
      ),
    ),
    footer: _GetMorePluginsRow(
      label: l10n.lyricsTranslationModalGetPlugins,
      onTap: (_) => openTranslationStore(context),
    ),
    hint: l10n.lyricsTranslationModalCacheFirst,
    confirm: (pickerContext, service) =>
        confirmTranslationNotice(pickerContext, ref, service),
  );
  if (picked == null || !context.mounted) return;
  await applyServicePick(
    context,
    ref,
    picked: picked,
    scope: scope.value,
    hash: hash,
  );
}

/// The installed plugin record for [installId], or null when none matches.
LyricsPluginRecord? _recordFor(
  List<LyricsPluginRecord> records,
  String installId,
) {
  for (final r in records) {
    if (r.installId == installId) return r;
  }
  return null;
}

class _GetMorePluginsRow extends StatelessWidget {
  const _GetMorePluginsRow({required this.label, required this.onTap});

  final String label;
  final void Function(BuildContext pickerContext) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      container: true,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onTap(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.add, color: colors.onSurfaceVariant),
                    const SizedBox(width: 14),
                    Expanded(
                      child: MarqueeText(
                        text: label,
                        startDelay: _footerMarqueeDelay,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(AppIcons.chevronRight, color: colors.outline),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
