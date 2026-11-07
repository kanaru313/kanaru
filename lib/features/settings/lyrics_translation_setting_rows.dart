import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/translation_language.dart';
import '../../core/lyrics_translation/translation_service.dart';
import '../../core/lyrics_translation/translation_service_choices.dart';
import '../../core/lyrics_translation/translation_service_names.dart';
import '../../core/lyrics_translation/translation_service_resolution.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/translation_language_name.dart';
import '../../shared/translation_notice_dialog.dart';
import '../../shared/translation_service_name.dart';
import 'setting_choice.dart';
import 'setting_row.dart';
import 'translation_plugin_rows.dart';

/// A choice of the default language: a language code, or `null` to follow the
/// app. A record, not a bare `String?`, because the dropdown ignores `null`
/// selections.
typedef _Target = ({String? code});

const _followApp = (code: null);

/// Lyrics translation options: the service and the default target
/// language. The saved translations are in
/// Data & storage › Caches.
class LyricsTranslationSettingRows extends ConsumerStatefulWidget {
  const LyricsTranslationSettingRows({super.key});

  @override
  ConsumerState<LyricsTranslationSettingRows> createState() =>
      _LyricsTranslationSettingRowsState();
}

class _LyricsTranslationSettingRowsState
    extends ConsumerState<LyricsTranslationSettingRows> {
  /// Keys the service dropdown. It only changes when the user cancels the
  /// notice: the dropdown has already written the cancelled choice into its
  /// text field, so it is rebuilt from the saved value. Not changed on a normal
  /// pick, which would drop keyboard focus.
  int _serviceDropdownEpoch = 0;

  Future<void> _pickService(
    BuildContext context,
    WidgetRef ref,
    TranslationServiceId service,
  ) async {
    final prefs = ref.read(settingsProvider).translation;
    // Picking from null, or switching while translation is on to a service
    // never agreed to, asks the notice if needed and turns translation on;
    // Cancel leaves the settings unchanged.
    if (prefs.service == null ||
        (prefs.show && needsNoticeFor(prefs, service))) {
      await enableTranslationWithNotice(context, ref, service);
      if (mounted &&
          ref.read(settingsProvider).translation.service != service) {
        setState(() => _serviceDropdownEpoch++);
      }
    } else {
      ref
          .read(settingsProvider.notifier)
          .setTranslation(prefs.copyWith(service: service));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prefs = ref.watch(settingsProvider.select((s) => s.translation));
    final appLanguage =
        translationLanguageFor(Localizations.localeOf(context).languageCode) ??
        translationLanguageFor('en')!;
    final target = prefs.targetLanguage;
    final known = target != null && translationLanguageFor(target) != null;
    // The live translate plugins; disabled while they are not known, so a
    // stored plugin choice is never overwritten blind.
    final plugins = ref.watch(translationPluginInfosProvider);
    final choices = ref.watch(translationServiceChoicesProvider);
    final services = choices.services;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.single(
          title: l10n.settingsTranslationService,
          subtitle: l10n.settingsTranslationServicePluginHint,
          control: SettingDropdown<TranslationServiceId>(
            key: ValueKey(_serviceDropdownEpoch),
            selected: choices.selected,
            hintText: l10n.translationServiceNotSelected,
            enabled: choices.ready && services.isNotEmpty,
            onSelected: (service) => _pickService(context, ref, service),
            options: [
              for (final service in services)
                SettingOption(
                  value: service,
                  label: translationServiceName(l10n, plugins, service),
                ),
            ],
          ),
        ),
        const TranslationPluginRows(),
        SettingRow.single(
          title: l10n.settingsTranslationTarget,
          subtitle: l10n.settingsTranslationTargetHint,
          control: SettingDropdown<_Target>(
            selected: known ? (code: target) : _followApp,
            onSelected: (choice) => ref
                .read(settingsProvider.notifier)
                .setTranslation(
                  ref
                      .read(settingsProvider)
                      .translation
                      .withTargetLanguage(choice.code),
                ),
            options: [
              SettingOption(
                value: _followApp,
                label: l10n.settingsTranslationTargetFollow(
                  translationLanguageName(l10n, appLanguage),
                ),
              ),
              for (final language in translationLanguages)
                SettingOption(
                  value: (code: language.code),
                  label: translationLanguageName(l10n, language),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
