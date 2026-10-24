import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/search/search_fields.dart';
import 'package:kanaru/core/search/search_prefs.dart';

void main() {
  group('SearchPrefs', () {
    test('defaults: no history, every tag field', () {
      const prefs = SearchPrefs();
      expect(prefs.history, isEmpty);
      expect(prefs.fields, SearchFieldPreset.all.fields);
    });

    test('record puts the newest first', () {
      final prefs = const SearchPrefs().record('a').record('b');
      expect(prefs.history, ['b', 'a']);
    });

    test('record trims and ignores blank queries', () {
      final prefs = const SearchPrefs().record('  x  ');
      expect(prefs.history, ['x']);
      expect(identical(prefs.record('   '), prefs), isTrue);
    });

    test('a repeat ignoring case moves up with the new spelling', () {
      final prefs = const SearchPrefs()
          .record('Beatles')
          .record('queen')
          .record(' beatles ');
      expect(prefs.history, ['beatles', 'queen']);
    });

    test('keeps 20 entries, dropping the oldest', () {
      var prefs = const SearchPrefs();
      for (var i = 0; i < 25; i++) {
        prefs = prefs.record('q$i');
      }
      expect(prefs.history, hasLength(20));
      expect(prefs.history.first, 'q24');
      expect(prefs.history.last, 'q5');
    });

    test('cuts a very long query', () {
      final prefs = const SearchPrefs().record('a' * 900);
      expect(prefs.history.single, hasLength(searchHistoryEntryMaxLength));
    });

    test('cuts on code points, never inside a surrogate pair', () {
      final prefs = const SearchPrefs().record('😀' * 600);
      expect(
        prefs.history.single.runes,
        hasLength(searchHistoryEntryMaxLength),
      );
      expect(prefs.history.single, '😀' * searchHistoryEntryMaxLength);
    });

    test('remove, clear and withFields return the same instance if nothing changes', () {
      final prefs = const SearchPrefs().withFields({SearchField.title});
      expect(identical(prefs.remove('zzz'), prefs), isTrue);
      expect(identical(prefs.clear(), prefs), isTrue);
      expect(identical(prefs.withFields({SearchField.title}), prefs), isTrue);
      expect(identical(prefs.withFields({}), prefs), isTrue);
    });

    test('remove drops one entry, and an unknown one changes nothing', () {
      final prefs = const SearchPrefs().record('a').record('b');
      expect(prefs.remove('A').history, ['b']);
      expect(prefs.remove('zzz').history, ['b', 'a']);
    });

    test('clear empties the history and keeps the fields', () {
      final prefs = const SearchPrefs()
          .withFields({SearchField.title})
          .record('a')
          .clear();
      expect(prefs.history, isEmpty);
      expect(prefs.fields, {SearchField.title});
    });

    test('withFields refuses an empty set', () {
      final prefs = const SearchPrefs().withFields({SearchField.genre});
      expect(prefs.withFields({}).fields, {SearchField.genre});
    });
  });
}
