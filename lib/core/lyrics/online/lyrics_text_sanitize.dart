// C0 controls except \n and \t, DEL, and the bidirectional overrides and
// isolates (U+202A-202E, U+2066-2069) that can reorder text on screen.
final _unsafe = RegExp(
  r'[\u0000-\u0008\u000B-\u001F\u007F\u202A-\u202E\u2066-\u2069]',
);

/// [text] without control and bidirectional override characters.
String sanitizeLyricsText(String text) => text.replaceAll(_unsafe, '');
