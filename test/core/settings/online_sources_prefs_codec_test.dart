import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/online_sources_prefs.dart';
import 'package:kanaru/core/settings/online_sources_prefs_codec.dart';

void main() {
  const a = 'plugin-abc123def456';
  const b = 'plugin-keep12345678';

  OnlineSourcesPrefs decode(Object? json) => decodeOnlineSourcesPrefs(json).$1;

  test('missing or wrong-typed input gives no consent', () {
    for (final json in [
      null,
      3,
      'x',
      <Object?>[],
      <String, Object?>{},
      <String, Object?>{'noticeAcknowledged': 'plugin-abc123def456'},
      <String, Object?>{'noticeAcknowledged': 7},
    ]) {
      expect(decode(json), const OnlineSourcesPrefs());
    }
    expect(const OnlineSourcesPrefs().allows(a), isFalse);
  });

  test('the accepted ids round-trip', () {
    const prefs = OnlineSourcesPrefs(noticeAcknowledged: {a, b});

    final json = encodeOnlineSourcesPrefs(prefs);

    expect(json['noticeAcknowledged'], unorderedEquals([a, b]));
    expect(decode(json), prefs);
    expect(decode(json).allows(a), isTrue);
  });

  test('items that are not plugin ids are carried through untouched', () {
    final (prefs, extra) = decodeOnlineSourcesPrefs(<String, Object?>{
      'noticeAcknowledged': [a, 'youtube', 5, null, 'PLUGIN-ABC123DEF456'],
    });

    expect(prefs.noticeAcknowledged, {a});
    final json = encodeOnlineSourcesPrefs(prefs, extra: extra);
    expect(json['noticeAcknowledged'], [
      a,
      'youtube',
      5,
      null,
      'PLUGIN-ABC123DEF456',
    ]);
  });

  test('at most 64 ids are kept', () {
    final ids = [
      for (var i = 0; i < 70; i++) 'plugin-${i.toString().padLeft(12, '0')}',
    ];

    final prefs = decode(<String, Object?>{'noticeAcknowledged': ids});

    expect(prefs.noticeAcknowledged, hasLength(maxAcknowledgedSourcePlugins));
    expect(prefs.noticeAcknowledged, containsAll(ids.take(64)));
    expect(prefs.allows(ids.last), isFalse);
  });

  test('unknown keys inside the group are kept', () {
    final (prefs, extra) = decodeOnlineSourcesPrefs(<String, Object?>{
      'future': true,
      'noticeAcknowledged': [a],
    });

    final json = encodeOnlineSourcesPrefs(prefs, extra: extra);

    expect(json['future'], isTrue);
    expect(json['noticeAcknowledged'], [a]);
  });
}
