import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/lyrics.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_content_hash.dart';

Lyrics _lyrics(List<LyricLine> lines) =>
    Lyrics(lines: lines, synced: true, source: LyricsSource.sidecar);

Lyrics _plain(List<String> texts) =>
    _lyrics([for (final t in texts) LyricLine(Duration.zero, t)]);

void main() {
  test('matches the known sha256 of the texts joined by newlines', () {
    expect(
      lyricsContentHash(_plain(['a', 'b'])),
      '7e18f737311b2dc3b2f269dd78396b0351f14fb66efa879f768cb23181883c78',
    );
  });

  test('ignores timestamps', () {
    final a = _lyrics([
      const LyricLine(Duration(seconds: 1), 'a'),
      const LyricLine(Duration(seconds: 2), 'b'),
    ]);
    final b = _lyrics([
      const LyricLine(Duration(seconds: 10), 'a'),
      const LyricLine(Duration(seconds: 20), 'b'),
    ]);
    expect(lyricsContentHash(a), lyricsContentHash(b));
  });

  test('ignores blank and whitespace-only lines', () {
    expect(
      lyricsContentHash(_plain(['a', '', '  ', 'b'])),
      lyricsContentHash(_plain(['a', 'b'])),
    );
  });

  test('changes when a character changes', () {
    expect(
      lyricsContentHash(_plain(['a', 'b'])),
      isNot(lyricsContentHash(_plain(['a', 'c']))),
    );
  });

  test('changes when the order changes', () {
    expect(
      lyricsContentHash(_plain(['a', 'b'])),
      isNot(lyricsContentHash(_plain(['b', 'a']))),
    );
  });

  test('hashes 10 000 lines quickly', () {
    final lyrics = _plain([for (var i = 0; i < 10000; i++) 'line number $i']);
    // Warm up once, then take the best of several runs so a scheduling
    // hiccup on a loaded machine does not fail the bound.
    final expected = lyricsContentHash(lyrics);
    var best = const Duration(days: 1);
    for (var i = 0; i < 5; i++) {
      final watch = Stopwatch()..start();
      final hash = lyricsContentHash(lyrics);
      watch.stop();
      expect(hash, expected);
      if (watch.elapsed < best) best = watch.elapsed;
    }
    expect(best.inMilliseconds, lessThan(200));
  });
}
