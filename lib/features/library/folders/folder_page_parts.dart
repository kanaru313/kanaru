import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// A section title on a folder page ("Folders", "Songs").
class FolderSectionHeading extends StatelessWidget {
  const FolderSectionHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}

/// What a folder page says when it has no subfolders and no songs.
class FolderEmptyNote extends StatelessWidget {
  const FolderEmptyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
        child: Text(
          context.l10n.foldersEmptyFolder,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Space under the last section of a folder page.
const folderPageEnd = SliverToBoxAdapter(child: SizedBox(height: 24));
