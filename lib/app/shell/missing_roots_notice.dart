import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_browse_missing_roots.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import 'app_destination.dart';

final _log = Logger('app.missingRoots');

/// Whether this launch already checked the music folders. Lives as long as
/// the provider container, so a shell built again does not repeat the notice.
final missingRootsCheckedProvider = NotifierProvider<MissingRootsChecked, bool>(
  MissingRootsChecked.new,
);

class MissingRootsChecked extends Notifier<bool> {
  @override
  bool build() => false;

  void markChecked() => state = true;
}

/// Wraps the shell and, once per launch after the first frame, warns with a
/// snack bar when a music folder is gone. Independent of the startup scan, so
/// it also speaks up when "rescan on startup" is off.
class MissingRootsNotice extends ConsumerStatefulWidget {
  const MissingRootsNotice({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MissingRootsNotice> createState() => _MissingRootsNoticeState();
}

class _MissingRootsNoticeState extends ConsumerState<MissingRootsNotice> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (!mounted || ref.read(missingRootsCheckedProvider)) return;
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    ref.read(missingRootsCheckedProvider.notifier).markChecked();
    final List<String> missing;
    try {
      missing = await missingRootPaths(db, ref.read(rootIsDirectoryProvider));
    } catch (error, stack) {
      // Not retried: the notice is a courtesy and the library still works.
      _log.warning('Could not check the music folders', error, stack);
      return;
    }
    if (!mounted || missing.isEmpty) return;

    final l10n = context.l10n;
    // Taken now: the notice may be gone by the time the action is tapped.
    final router = GoRouter.maybeOf(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // Long enough to read a path.
        duration: const Duration(seconds: 8),
        content: Text(l10n.libraryMissingRoots(missing.length, missing.first)),
        action: SnackBarAction(
          label: l10n.libraryMissingRootsAction,
          onPressed: () => router?.go(AppDestination.settings.path),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
