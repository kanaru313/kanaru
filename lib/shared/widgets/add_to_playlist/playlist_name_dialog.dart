import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// Longest playlist name the dialog accepts.
const playlistNameMaxLength = 200;

/// Asks for a playlist name. Completes with the trimmed name, or null when
/// the user cancels (button, Esc or a tap outside).
Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? initialName,
}) => showDialog<String>(
  context: context,
  builder: (context) => _PlaylistNameDialog(
    title: title,
    confirmLabel: confirmLabel,
    initialName: initialName,
  ),
);

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({
    required this.title,
    required this.confirmLabel,
    this.initialName,
  });

  final String title;
  final String confirmLabel;
  final String? initialName;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialName ?? '';
    // Fully selected, so typing replaces the suggested name.
    _controller = TextEditingController(text: initial)
      ..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Pops the trimmed name; does nothing while it is empty. Enter reaches
  /// here even when the confirm button is disabled.
  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: playlistNameMaxLength,
        decoration: InputDecoration(
          labelText: context.l10n.playlistNameLabel,
          counterText: '',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: Text(widget.confirmLabel),
          ),
        ),
      ],
    );
  }
}
