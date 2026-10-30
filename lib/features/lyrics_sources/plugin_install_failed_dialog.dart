import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_plugins_controller.dart';
import '../../l10n/l10n.dart';
import 'plugin_install_outcome_messages.dart';

/// "Không cài được": says why [outcome] was not installed, one line per
/// reason. [sourceName] is the file (or repo item) that was tried; it is named
/// only when the package itself was refused. Does nothing for an outcome that
/// installed the plugin.
Future<void> showPluginInstallFailedDialog(
  BuildContext context, {
  required String sourceName,
  required PluginInstallOutcome outcome,
}) {
  final reasons = pluginInstallOutcomeReasons(context.l10n, outcome);
  if (reasons.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (context) => _InstallFailedDialog(
      sourceName: outcome is PluginInstallRejected ? sourceName : null,
      reasons: reasons,
    ),
  );
}

class _InstallFailedDialog extends StatelessWidget {
  const _InstallFailedDialog({required this.sourceName, required this.reasons});

  final String? sourceName;
  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final name = sourceName;
    return AlertDialog(
      title: Text(l10n.pluginInstallFailedTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (name != null) ...[
              Text(l10n.pluginInstallFailedFile(name)),
              const SizedBox(height: 12),
            ],
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.error),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pluginInstallFailedReasons,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final reason in reasons)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('•  $reason'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
