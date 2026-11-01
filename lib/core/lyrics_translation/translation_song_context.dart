/// What a translator may know about the song, besides the lines. Both are
/// absent when unknown; a title that is only the file name is never given.
class TranslationSongContext {
  const TranslationSongContext({this.title, this.artist});

  final String? title;
  final String? artist;

  @override
  bool operator ==(Object other) =>
      other is TranslationSongContext &&
      other.title == title &&
      other.artist == artist;

  @override
  int get hashCode => Object.hash(title, artist);
}
