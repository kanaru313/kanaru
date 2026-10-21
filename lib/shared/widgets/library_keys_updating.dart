import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_keys_provider.dart';
import '../../l10n/l10n.dart';

/// What the browse pages show while the library's sort and grouping keys are
/// being made: a title and a progress bar. Playback is unaffected.
class LibraryKeysUpdating extends ConsumerWidget {
  const LibraryKeysUpdating({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final status = ref.watch(libraryKeysProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.libraryKeysUpdatingTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.libraryKeysUpdatingMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: status.fraction),
              if (status.total > 0) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.libraryKeysUpdatingProgress(status.done, status.total),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
