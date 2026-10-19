import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/logging/app_logging.dart';
import '../../l10n/l10n.dart';
import 'open_external.dart';
import 'settings_section.dart';

const _repositoryUrl = 'https://github.com/kanaru313/kanaru';
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
          subtitle: const Text(_repositoryUrl),
          trailing: const Icon(Icons.open_in_new),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            if (await ref.read(openExternalProvider)(_repositoryUrl)) return;
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.settingsOpenFailed(_repositoryUrl))),
            );
          },
        ),
      ],
    );
  }
}
