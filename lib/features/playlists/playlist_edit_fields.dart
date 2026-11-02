import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_text_rules.dart';
import '../../l10n/l10n.dart';

/// Name and Description fields of the edit dialog. [onSubmit] runs when Enter
/// is pressed in Name; Enter in Description adds a line.
class PlaylistEditFields extends StatelessWidget {
  const PlaylistEditFields({
    super.key,
    required this.name,
    required this.description,
    required this.onSubmit,
  });

  final TextEditingController name;
  final TextEditingController description;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder(
          valueListenable: name,
          builder: (context, value, _) => TextField(
            key: const ValueKey('playlist-edit-name'),
            controller: name,
            autofocus: true,
            maxLength: playlistNameMaxLength,
            decoration: InputDecoration(
              labelText: l10n.playlistNameLabel,
              counterText: '',
              errorText: value.text.trim().isEmpty
                  ? l10n.playlistNameEmptyError
                  : null,
            ),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(height: 20),
        // Fixed height, scrolls inside without a visible scrollbar.
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: TextField(
            key: const ValueKey('playlist-edit-description'),
            controller: description,
            keyboardType: TextInputType.multiline,
            minLines: 5,
            maxLines: 5,
            maxLength: playlistDescriptionMaxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            decoration: InputDecoration(
              labelText: l10n.playlistDescriptionLabel,
              hintText: l10n.playlistDescriptionHint,
              alignLabelWithHint: true,
            ),
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) => Text(
                  l10n.playlistEditCounter(
                    graphemeLength(description.text),
                    playlistDescriptionMaxLength,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
          ),
        ),
      ],
    );
  }
}
