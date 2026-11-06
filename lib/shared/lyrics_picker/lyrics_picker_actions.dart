import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_search_controller.dart';
import '../../l10n/l10n.dart';

/// Cancel and Use buttons of the Choose lyrics dialog. Use pops the
/// [selection]'s candidate and stays off until its lyrics are there.
class LyricsPickerActions extends StatelessWidget {
  const LyricsPickerActions({super.key, required this.selection});

  final RankedCandidate? selection;

  @override
  Widget build(BuildContext context) {
    final picked = selection;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: picked != null && picked.hasBody
              ? () => Navigator.of(context).pop(picked.candidate)
              : null,
          child: Text(context.l10n.lyricsPickerUse),
        ),
      ],
    );
  }
}
