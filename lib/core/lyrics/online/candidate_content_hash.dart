import '../../lyrics_translation/lyrics_content_hash.dart';
import 'lyrics_provider.dart';
import 'online_lyrics_entries.dart';

final _hashes = Expando<_Hash>('candidateContentHash');

// Boxed so that "no text" is cached too.
class _Hash {
  const _Hash(this.value);
  final String? value;
}

/// The `lyricsContentHash` of [candidate]'s text, as a rejected record is
/// remembered by it; `null` for an instrumental record or one without usable
/// text. Computed once per candidate instance.
String? candidateContentHash(LyricsCandidate candidate) {
  final cached = _hashes[candidate];
  if (cached != null) return cached.value;
  final body = candidate.body;
  final lyrics = body == null || body.instrumental
      ? null
      : parseStoredLyrics(synced: body.syncedLrc, plain: body.plain);
  final hash = lyrics == null ? null : lyricsContentHashOf(lyrics);
  _hashes[candidate] = _Hash(hash);
  return hash;
}
