/// Control characters and bidi overrides or isolates: text from or for an
/// M3U file is shown or named with them as spaces, so it cannot hide or
/// reorder what it says.
final m3uUnsafeTextChars = RegExp(
  r'[\u0000-\u001f\u007f\u202a-\u202e\u2066-\u2069]',
);
