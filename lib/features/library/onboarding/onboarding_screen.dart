import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/indexer/indexer_providers.dart';
import '../../../core/indexer/root_path.dart';
import '../../../l10n/l10n.dart';
import '../directory_picker_provider.dart';
import '../root_rejection_message.dart';
import 'onboarding_folder_list.dart';
import 'suggested_music_folder_provider.dart';

final _log = Logger('library');

/// Routes this screen leaves to. Literals because features must not import
/// `app/`; they are the paths of `AppDestination.songs` and `.home`.
const _songsPath = '/songs';
const _homePath = '/home';

/// First-run screen: pick the folders that make up the library, then scan.
/// Shown outside the shell (no sidebar or player bar) while the library has
/// no folder.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// [pickDirectory] opens the folder picker; defaults to
  /// [directoryPickerProvider].
  const OnboardingScreen({super.key, this.pickDirectory});

  final DirectoryPicker? pickDirectory;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final List<String> _folders = [];
  bool _suggestionSelected = true;
  bool _busy = false;

  /// The picker is open or its answer is being checked.
  bool _picking = false;

  String? get _suggestion => ref.watch(suggestedMusicFolderProvider).value;

  /// Folders that will become roots: the checked suggestion and the added ones.
  List<String> _selection(String? suggestion) => [
    if (suggestion != null && _suggestionSelected) suggestion,
    ..._folders,
  ];

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addFolder() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      await _pickAndAdd();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickAndAdd() async {
    final DirectoryPicker pick =
        widget.pickDirectory ?? ref.read(directoryPickerProvider);
    final picked = await pick();
    if (picked == null || !mounted) return;
    final canonical = await canonicalizeRoot(picked);
    if (!mounted) return;
    final path = canonical.path;
    final rejection =
        canonical.rejection ??
        conflictWith(
          path!,
          _selection(ref.read(suggestedMusicFolderProvider).value),
        );
    if (rejection != null) {
      _message(rootRejectionMessage(context.l10n, path ?? picked, rejection));
      return;
    }
    setState(() => _folders.add(path!));
  }

  /// Stores the chosen folders and scans them. When some folders were
  /// refused but others stored, goes on to Songs anyway (the stored ones must
  /// not be stranded without a scan) and reports the refusals there.
  Future<void> _start() async {
    if (_busy) return;
    final chosen = _selection(ref.read(suggestedMusicFolderProvider).value);
    if (chosen.isEmpty) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(libraryRootsControllerProvider)
          .addRoots(chosen);
      if (!mounted) return;
      final refusals = rootRejectionsMessage(l10n, result.rejected);
      if (result.added.isEmpty) {
        _message(refusals);
        return;
      }
      // Errors end up in the indexer state, never in the zone.
      unawaited(ref.read(libraryIndexerProvider.notifier).scan());
      context.go(_songsPath);
      if (result.rejected.isNotEmpty) {
        // The root messenger outlives this screen.
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(refusals)));
      }
    } catch (error, stackTrace) {
      _log.severe('Starting the first scan failed', error, stackTrace);
      if (mounted) _message(l10n.libraryUnexpectedError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final suggestion = _suggestion;
    final canStart = !_busy && _selection(suggestion).isNotEmpty;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.library_music_outlined,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.onboardingTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.onboardingMessage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                OnboardingFolderList(
                  suggestion: suggestion,
                  suggestionSelected: _suggestionSelected,
                  onSuggestionChanged: (value) =>
                      setState(() => _suggestionSelected = value),
                  folders: _folders,
                  onRemove: (folder) => setState(() => _folders.remove(folder)),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy || _picking ? null : _addFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: Text(l10n.onboardingAddFolder),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : () => context.go(_homePath),
                      child: Text(l10n.onboardingLater),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: canStart ? _start : null,
                      child: Text(l10n.onboardingStart),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
