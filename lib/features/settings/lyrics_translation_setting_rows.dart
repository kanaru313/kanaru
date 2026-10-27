import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/translation_language.dart';
import '../../core/lyrics_translation/translation_service.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/translation_language_name.dart';
import '../../shared/translation_notice_dialog.dart';
import 'deepl_key_setting_row.dart';
import 'setting_choice.dart';
import 'setting_row.dart';
import 'translation_cache_setting_row.dart';

/// A choice of the default language: a language code, or `null` to follow the
/// app. A record, not a bare `String?`, because the dropdown ignores `null`
/// selections.
typedef _Target = ({String? code});

const _followApp = (code: null);

/// Lyrics translation options: the service, the DeepL key (only while DeepL
/// is chosen), the default target language and the saved translations.
class LyricsTranslationSettingRows extends ConsumerWidget {
  const LyricsTranslationSettingRows({super.key});

  Future<void> _pickService(
    BuildContext context,
    WidgetRef ref,
    LyricsTranslationService service,
  ) async {
    final prefs = ref.read(settingsProvider).translation;
    // While translation is on, a service never agreed to needs the notice
    // first; Cancel keeps the old service.
    if (prefs.show && !prefs.noticeAcknowledged.contains(service)) {
      await enableTranslationWithNotice(context, ref, service);
    } else {
      ref
          .read(settingsProvider.notifier)
          .setTranslation(prefs.copyWith(service: service));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(settingsProvider.select((s) => s.translation));
    final appLanguage =
        translationLanguageFor(Localizations.localeOf(context).languageCode) ??
        translationLanguageFor('en')!;
    final target = prefs.targetLanguage;
    final known = target != null && translationLanguageFor(target) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow(
          title: l10n.settingsTranslationService,
          subtitle: prefs.service == LyricsTranslationService.google
              ? l10n.settingsTranslationServiceGoogleHint
              : l10n.settingsTranslationServiceDeeplHint,
          control: (compact) => SettingChoice<LyricsTranslationService>(
            compact: compact,
            selected: prefs.service,
            onSelected: (service) => _pickService(context, ref, service),
            options: [
              for (final service in LyricsTranslationService.values)
                SettingOption(
                  value: service,
                  label: translationServiceName(service),
                ),
            ],
          ),
        ),
        if (prefs.service == LyricsTranslationService.deepl)
          const DeepLKeySettingRow(),
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
        const TranslationCacheSettingRow(),
      ],
    );
  }
}
