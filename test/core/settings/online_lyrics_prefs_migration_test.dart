import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/online_lyrics_prefs.dart';
import 'package:kanaru/core/settings/online_lyrics_prefs_codec.dart';

/// An upgrade must keep what the user already accepted: the old per-source
/// consent list becomes the two global flags, with no new notice.
void main() {
  const manualKey = 'lrclib@lrclib.net';
  const autoKey = 'lrclib@lrclib.net:auto';

  (OnlineLyricsPrefs, Map<String, Object?>) decode(Map<String, Object?> map) =>
      decodeOnlineLyricsPrefs(map);

  test('a manual-only legacy key grants the manual consent only', () {
    final (prefs, _) = decode({
      'noticeAcknowledged': [manualKey],
    });

    expect(prefs.manualConsent, isTrue);
    expect(prefs.autoConsent, isFalse);
    expect(prefs.autoFetch, isFalse);
  });

  test('both legacy keys with autoFetch on give both consents and auto on', () {
    final (prefs, _) = decode({
      'autoFetch': true,
      'noticeAcknowledged': [manualKey, autoKey],
    });

    expect(prefs.manualConsent, isTrue);
    expect(prefs.autoConsent, isTrue);
    expect(prefs.autoFetch, isTrue);
    expect(prefs.autoAllowed, isTrue);
  });

  test('an automatic legacy key alone grants both consents', () {
    final (prefs, _) = decode({
      'noticeAcknowledged': [autoKey],
    });

    expect(prefs.manualConsent, isTrue);
    expect(prefs.autoConsent, isTrue);
    expect(prefs.autoFetch, isFalse);
  });

  test('legacy strings without @ and other types are ignored', () {
    final (prefs, _) = decode({
      'autoFetch': true,
      'noticeAcknowledged': ['lrclib', 'deepl', 7, null],
    });

    expect(prefs, const OnlineLyricsPrefs());
  });

  test('a legacy value that is not a list is ignored', () {
    final (prefs, _) = decode({'noticeAcknowledged': manualKey});

    expect(prefs, const OnlineLyricsPrefs());
  });

  test('the legacy key of another source still grants the consent', () {
    final (prefs, _) = decode({
      'noticeAcknowledged': ['other@example.org'],
    });

    expect(prefs.manualConsent, isTrue);
    expect(prefs.autoConsent, isFalse);
  });

  test('stored flags win over the legacy list', () {
    final (prefs, _) = decode({
      'manualConsent': false,
      'noticeAcknowledged': [manualKey, autoKey],
    });

    expect(prefs.manualConsent, isFalse);
    expect(prefs.autoConsent, isFalse);
  });

  test('one stored flag stops the legacy list from adding the other', () {
    final (prefs, _) = decode({
      'autoConsent': true,
      'noticeAcknowledged': [manualKey],
    });

    expect(prefs.autoConsent, isTrue);
    expect(prefs.manualConsent, isFalse);
  });

  test('the legacy key is gone on write and not carried as an extra', () {
    final (prefs, extra) = decode({
      'autoFetch': true,
      'noticeAcknowledged': [manualKey, autoKey, 7],
      'future': 1,
    });
    final written = encodeOnlineLyricsPrefs(prefs, extra: extra);

    expect(extra, {'future': 1});
    expect(written.keys, isNot(contains('noticeAcknowledged')));
    expect(written['manualConsent'], isTrue);
    expect(written['autoConsent'], isTrue);
    expect(written['autoFetch'], isTrue);
    expect(written['future'], 1);
  });

  test('a migrated file decodes to the same prefs after being written', () {
    final (prefs, extra) = decode({
      'autoFetch': true,
      'noticeAcknowledged': [manualKey, autoKey],
    });
    final (again, _) = decode(encodeOnlineLyricsPrefs(prefs, extra: extra));

    expect(again, prefs);
  });
}
