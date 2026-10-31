/// Zero-width space: invisible, but a line may break after it.
const zeroWidthSpace = '​';

/// Tokens longer than this (in characters, between spaces) get break points.
const wrapAnywhereMinLength = 24;

/// [text] with a zero-width space between the characters of every run of
/// non-space characters longer than [wrapAnywhereMinLength], so a long path
/// or URL wraps instead of overflowing. For display only: copy and
/// semantics use the original text.
String wrapAnywhere(String text) => text.splitMapJoin(
  RegExp(r'\S+'),
  onMatch: (m) {
    final runes = m[0]!.runes.toList();
    if (runes.length <= wrapAnywhereMinLength) return m[0]!;
    return runes.map(String.fromCharCode).join(zeroWidthSpace);
  },
);
