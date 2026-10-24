import 'package:material_ui/material_ui.dart';

import '../../core/search/search_query_parser.dart';

/// A search field's `field:` prefixes (`artist:`, `year:`, ...) painted in
/// the primary color while typing, so they read as search syntax instead of
/// part of the searched word (the mention-highlight pattern Discord uses).
class SearchQueryHighlightingController extends TextEditingController {
  SearchQueryHighlightingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // The IME composing region needs its own underline; leave it to the
    // default painter rather than fighting over the same span.
    if (withComposing && value.composing.isValid) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final prefixStyle = style?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    final children = <TextSpan>[];
    var last = 0;
    for (final match in _prefixPattern.allMatches(text)) {
      final word = match.group(2)!;
      if (!recognizedSearchPrefixes.contains(word.toLowerCase())) continue;
      final start = match.start + match.group(1)!.length;
      final end = start + word.length + 1;
      if (start > last) {
        children.add(
          TextSpan(text: text.substring(last, start), style: style),
        );
      }
      children.add(TextSpan(text: text.substring(start, end), style: prefixStyle));
      last = end;
    }
    if (last < text.length) {
      children.add(TextSpan(text: text.substring(last), style: style));
    }
    return TextSpan(style: style, children: children);
  }
}

final _prefixPattern = RegExp(r'(^|\s)([A-Za-z]+):');
