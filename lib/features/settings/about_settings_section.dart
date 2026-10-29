import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_identity.dart';
import '../../core/logging/app_logging.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'open_external.dart';
import 'settings_section.dart';
import '../../shared/widgets/app_snack_bar.dart';

const _licenseName = 'GPL-3.0-or-later';

class AboutSettingsSection extends ConsumerWidget {
  const AboutSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return SettingsSection(
      title: l10n.settingsAbout,
      children: [
        ListTile(
          title: Text(l10n.appTitle),
          subtitle: Text('${l10n.settingsVersion} $kanaruVersion'),
        ),
        ListTile(
          title: Text(l10n.settingsLicense),
          subtitle: const Text(_licenseName),
        ),
        ListTile(
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
      ],
    );
  }
}
