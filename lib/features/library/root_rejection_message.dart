import '../../core/indexer/root_path.dart';
import '../../l10n/l10n.dart';

/// User-facing reason why [path] was refused as a library folder.
String rootRejectionMessage(
  AppLocalizations l10n,
  String path,
  RootRejection rejection,
) => switch (rejection) {
  RootRejection.notFound => l10n.libraryRootNotFound(path),
  RootRejection.notDirectory => l10n.libraryRootNotDirectory(path),
  RootRejection.duplicate => l10n.libraryRootDuplicate(path),
  RootRejection.nested => l10n.libraryRootNested(path),
  RootRejection.libraryUnavailable => l10n.libraryRootUnavailable,
  RootRejection.tooBroad => l10n.libraryRootTooBroad(path),
  RootRejection.writeFailed => l10n.libraryRootWriteFailed(path),
};

/// One line per refused folder in [rejected], for a single message.
String rootRejectionsMessage(
  AppLocalizations l10n,
  Map<String, RootRejection> rejected,
) => [
  for (final entry in rejected.entries)
    rootRejectionMessage(l10n, entry.key, entry.value),
].join('\n');
