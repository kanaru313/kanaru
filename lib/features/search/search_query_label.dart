import 'package:material_ui/material_ui.dart';

import '../../core/search/search_query.dart';
import '../../core/search/search_query_parser.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'search_query_display.dart';

/// [query] (with its `field:value` syntax) as a row of chips, one per
/// filter, plus the free words quoted — the chip replaces a raw `artist:`
/// prefix with an icon and its translated field name.
class SearchQueryLabel extends StatelessWidget {
  const SearchQueryLabel({super.key, required this.query});

  final String query;

  static const _fieldIcons = {
    QueryField.artist: AppIcons.artistOutline,
    QueryField.album: AppIcons.albumOutlined,
    QueryField.genre: AppIcons.genreOutlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final parsed = parseSearchQuery(query);
    final freeText = parsed.freeTerms.join(' ');

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final field in QueryField.values)
          if (parsed.termsFor(field).isNotEmpty)
            _Chip(
              icon: _fieldIcons[field]!,
              text: '${_fieldLabel(l10n, field)}: ${parsed.termsFor(field).join(' ')}',
            ),
        if (parsed.years.isNotEmpty)
          _Chip(
            icon: AppIcons.calendar,
            text: parsed.years.map(yearFilterText).join(', '),
          ),
        if (parsed.formats.isNotEmpty)
          _Chip(icon: AppIcons.musicNoteOutlined, text: parsed.formats.join(', ')),
        if (parsed.languages.isNotEmpty)
          _Chip(icon: AppIcons.languageOutlined, text: parsed.languages.join(', ')),
        if (freeText.isNotEmpty) Text('“$freeText”', style: theme.textTheme.bodyMedium),
      ],
    );
  }

  String _fieldLabel(AppLocalizations l10n, QueryField field) => switch (field) {
    QueryField.artist => l10n.searchFieldArtist,
    QueryField.album => l10n.searchFieldAlbum,
    QueryField.genre => l10n.searchFieldGenre,
  };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onChip = theme.colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: onChip),
          const SizedBox(width: 4),
          Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: onChip)),
        ],
      ),
    );
  }
}
