import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_identity.dart';
import '../../core/logging/app_logging.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/open_external.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../shared/widgets/kanaru_logo.dart';
import 'setting_card.dart';
import 'settings_section.dart';

const _licenseName = 'GPL-3.0-or-later';

/// The About page's rows: header with logo and version, license, third-party
/// licenses, source code.
class AboutSettingsSection extends ConsumerWidget {
  const AboutSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return SettingsSection(
      // The page title already says it.
      title: null,
      children: [
        const _AboutHeader(),
        SettingCard(
          child: ListTile(
            title: Text(l10n.settingsLicense),
            subtitle: const Text(_licenseName),
          ),
        ),
        SettingCard(
          child: ListTile(
            title: Text(l10n.settingsOpenSourceLicenses),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: kanaruVersion,
            ),
          ),
        ),
        SettingCard(
          child: ListTile(
            title: Text(l10n.settingsSourceCode),
            subtitle: const Text(kanaruRepositoryUrl),
            trailing: const Icon(AppIcons.openExternal),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final opened = await ref.read(openExternalProvider)(
                kanaruRepositoryUrl,
              );
              if (opened) return;
              messenger.showSnackBar(
                appSnackBar(
                  kind: AppSnackBarKind.error,
                  title: l10n.settingsOpenFailed(kanaruRepositoryUrl),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Centered logo, app name and version. Read as one node by screen readers.
class _AboutHeader extends StatelessWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      // The section column aligns children to the start; fill the width.
      child: SizedBox(
        width: double.infinity,
        child: MergeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const KanaruLogo(size: 72),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  l10n.appTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${l10n.settingsVersion} $kanaruVersion',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
