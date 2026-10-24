import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/search/search_fields.dart';
import 'package:kanaru/core/search/search_prefs_provider.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kanaru_search_prov');
    path = '${dir.path}/search_history.json';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ProviderContainer containerFor(SearchPrefsFile? file) {
    final container = ProviderContainer(
      overrides: [searchPrefsFileProvider.overrideWithValue(file)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('record writes the file and a new container reads it back', () async {
    final first = containerFor(SearchPrefsFile(path));
    final notifier = first.read(searchPrefsProvider.notifier);
    await notifier.record('beatles');
    await notifier.setFields({SearchField.title});
    expect(first.read(searchPrefsProvider).value!.history, ['beatles']);
    expect((jsonDecode(File(path).readAsStringSync()) as Map)['history'], [
      'beatles',
    ]);

    final second = containerFor(SearchPrefsFile(path));
    final prefs = await second.read(searchPrefsProvider.future);
    expect(prefs.history, ['beatles']);
    expect(prefs.fields, {SearchField.title});
  });

  test('a change right at startup keeps the stored history', () async {
    File(path).writeAsStringSync(
      jsonEncode({
        'history': ['old'],
      }),
    );
    final container = containerFor(SearchPrefsFile(path));
    await container.read(searchPrefsProvider.notifier).record('new');
    expect(container.read(searchPrefsProvider).value!.history, ['new', 'old']);
  });

  test('remove and clear update the file', () async {
    final container = containerFor(SearchPrefsFile(path));
    final notifier = container.read(searchPrefsProvider.notifier);
    await notifier.record('a');
    await notifier.record('b');
    await notifier.remove('a');
    expect((jsonDecode(File(path).readAsStringSync()) as Map)['history'], [
      'b',
    ]);
    await notifier.clear();
    expect(
      (jsonDecode(File(path).readAsStringSync()) as Map)['history'],
      isEmpty,
    );
  });

  test('a change that alters nothing does not write the file', () async {
    final container = containerFor(SearchPrefsFile(path));
    final notifier = container.read(searchPrefsProvider.notifier);
    await notifier.clear();
    await notifier.remove('nope');
    await notifier.setFields(defaultSearchFields);
    expect(File(path).existsSync(), isFalse);
    await notifier.record('a');
    final stamp = File(path).lastModifiedSync();
    final text = File(path).readAsStringSync();
    File(path).writeAsStringSync('$text ');
    await notifier.remove('nope');
    expect(File(path).readAsStringSync(), '$text ');
    expect(stamp, isNotNull);
  });

  test('an empty field set is refused', () async {
    final container = containerFor(SearchPrefsFile(path));
    final notifier = container.read(searchPrefsProvider.notifier);
    await notifier.setFields({SearchField.genre});
    await notifier.setFields({});
    expect(container.read(searchPrefsProvider).value!.fields, {
      SearchField.genre,
    });
  });

  test('without a file the prefs stay in memory', () async {
    final container = containerFor(null);
    await container.read(searchPrefsProvider.notifier).record('a');
    expect(container.read(searchPrefsProvider).value!.history, ['a']);
    expect(File(path).existsSync(), isFalse);
  });
}
