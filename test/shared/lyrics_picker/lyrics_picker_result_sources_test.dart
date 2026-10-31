import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_match.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_search_controller.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_result_sources.dart';

import '../../core/lyrics/online/fake_lyrics_provider.dart';

const _query = LyricsQuery(title: 'Song');

RankedCandidate _result(String providerId, String id) {
  final candidate = fakeCandidate(
    providerId: providerId,
    remoteId: id,
    title: id,
  );
  return RankedCandidate(candidate, matchCandidate(_query, candidate));
}

void main() {
  group('lyricsResultSources', () {
    test('counts per source in the order of first appearance', () {
      final sources = lyricsResultSources([
        _result('b', '1'),
        _result('a', '2'),
        _result('b', '3'),
        _result('b', '4'),
      ]);
      expect(sources, [(id: 'b', count: 3), (id: 'a', count: 1)]);
    });

    test('no results, no sources', () {
      expect(lyricsResultSources(const []), isEmpty);
    });
  });

  group('effectiveSourceFilter', () {
    const sources = [(id: 'a', count: 2), (id: 'b', count: 1)];

    test('keeps a source that has results', () {
      expect(effectiveSourceFilter('b', sources), 'b');
    });

    test('a source without results counts as every source', () {
      expect(effectiveSourceFilter('c', sources), isNull);
      expect(effectiveSourceFilter('a', const []), isNull);
    });

    test('null stays null', () {
      expect(effectiveSourceFilter(null, sources), isNull);
    });
  });
}
