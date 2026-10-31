import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'repo_error_text.dart';

final _log = Logger('lyrics_plugin_store');

/// Opens "Thêm repository". On success the dialog closes and a snackbar says
/// "Đã thêm (name) · N plugin".
Future<void> showAddRepositoryDialog(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final added = await showDialog<AddRepoAdded>(
    context: context,
    builder: (context) => const _AddRepositoryDialog(),
  );
  if (added == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      appSnackBar(
        kind: AppSnackBarKind.success,
        title: l10n.lyricsStoreAddedRepo(added.name, added.pluginCount),
      ),
    );
}

class _AddRepositoryDialog extends ConsumerStatefulWidget {
  const _AddRepositoryDialog();

  @override
  ConsumerState<_AddRepositoryDialog> createState() =>
      _AddRepositoryDialogState();
}

class _AddRepositoryDialogState extends ConsumerState<_AddRepositoryDialog> {
  final _url = TextEditingController();
  bool _adding = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(lyricsPluginReposControllerProvider);
    if (_adding || controller == null) return;
    final l10n = context.l10n;
    setState(() {
      _adding = true;
      _error = null;
    });
    AddRepoResult result;
    try {
      result = await controller.add(_url.text);
    } on Object catch (error, stackTrace) {
      _log.warning('Adding a repository failed', error, stackTrace);
      result = const AddRepoFailed(AddRepoFailure.storage);
    }
    if (!mounted) return;
    switch (result) {
      case AddRepoAdded():
        Navigator.of(context).pop(result);
      case AddRepoFailed failed:
        setState(() {
          _adding = false;
          _error = addRepoFailureText(l10n, failed);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canAdd = ref.watch(lyricsPluginReposControllerProvider) != null;
    return PopScope(
      // The add cannot be taken back once started: wait for its answer.
      canPop: !_adding,
      child: AlertDialog(
        title: Text(l10n.lyricsStoreAddRepository),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: _url,
            autofocus: true,
            enabled: !_adding,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.lyricsStoreAddUrlLabel,
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _adding ? null : () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _adding || !canAdd ? null : _submit,
            child: _adding
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.lyricsStoreAddLoading),
                    ],
                  )
                : Text(l10n.lyricsStoreAddConfirm),
          ),
        ],
      ),
    );
  }
}
