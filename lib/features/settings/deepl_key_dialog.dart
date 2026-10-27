import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/deepl_key_provider.dart';
import '../../core/lyrics_translation/deepl_usage.dart';
import '../../core/lyrics_translation/translation_failure.dart';
import '../../core/secrets/secret_store.dart';
import '../../l10n/l10n.dart';
import '../../shared/translation_failure_message.dart';

/// The sentence that says why the DeepL key could not be read, checked or
/// saved: a key store failure, a DeepL answer, or anything else.
String deeplKeyErrorMessage(
  AppLocalizations l10n,
  Object error, {
  String? fallback,
}) => switch (error) {
  SecretStoreException(:final kind) => switch (kind) {
    SecretStoreFailure.locked => l10n.deeplKeyKeyringLocked,
    SecretStoreFailure.noDefaultCollection => l10n.deeplKeyKeyringNoDefault,
    SecretStoreFailure.timeout => l10n.deeplKeyKeyringTimeout,
    SecretStoreFailure.unavailable => l10n.deeplKeyKeyringUnavailable,
    SecretStoreFailure.io => l10n.deeplKeyFileFailed,
  },
  TranslationException(kind: TranslationFailureKind.badKey) =>
    l10n.deeplKeyBadKey,
  TranslationException(:final kind) => translationFailureMessage(l10n, kind),
  _ => fallback ?? l10n.deeplKeySaveFailed,
};

/// Asks for a DeepL key, checks it with DeepL and stores it. Completes with
/// the usage DeepL reported for the saved key, or `null` when the user
/// cancelled (nothing is stored then).
Future<DeepLUsage?> showDeepLKeyDialog(
  BuildContext context, {
  required bool replacing,
}) => showDialog<DeepLUsage>(
  context: context,
  builder: (context) => _DeepLKeyDialog(replacing: replacing),
);

class _DeepLKeyDialog extends ConsumerStatefulWidget {
  const _DeepLKeyDialog({required this.replacing});

  final bool replacing;

  @override
  ConsumerState<_DeepLKeyDialog> createState() => _DeepLKeyDialogState();
}

class _DeepLKeyDialogState extends ConsumerState<_DeepLKeyDialog> {
  // Holds the typed key only while the dialog is open: emptied after a save
  // and disposed with the dialog.
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _controller.text.trim().isEmpty) return;
    final l10n = context.l10n;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final usage = await ref
          .read(deeplApiKeyProvider.notifier)
          .save(_controller.text);
      _controller.clear();
      if (mounted) Navigator.of(context).pop(usage);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = deeplKeyErrorMessage(l10n, error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          widget.replacing
              ? l10n.deeplKeyDialogTitleEdit
              : l10n.deeplKeyDialogTitleAdd,
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.deeplKeyDialogHint),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                obscureText: true,
                enabled: !_saving,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: l10n.deeplKeyFieldLabel,
                  errorText: _error,
                  errorMaxLines: 3,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving || _controller.text.trim().isEmpty
                ? null
                : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.deeplKeySave),
          ),
        ],
      ),
    );
  }
}
