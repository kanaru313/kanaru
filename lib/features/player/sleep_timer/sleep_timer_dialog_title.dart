import 'package:material_ui/material_ui.dart';

import '../../../shared/icons/app_icons.dart';

/// Title row of both views of the sleep timer dialog: the timer icon, the
/// [text] and, at the end, an optional [trailing] widget.
class SleepTimerDialogTitle extends StatelessWidget {
  const SleepTimerDialogTitle({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
      child: Row(
        children: [
          Icon(AppIcons.sleepTimer, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
