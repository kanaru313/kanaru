import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/language_tags.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/language_display_name.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    test('every known key has a name in $locale', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      final names = <String>{};
      for (final key in [...knownLanguageKeys, 'zxx', 'mul']) {
        final name = languageDisplayName(l10n, key);
        expect(name, isNot(key.toUpperCase()), reason: key);
        expect(names.add(name), isTrue, reason: 'duplicate name for $key');
      }
    });
  }

  test('names are translated per locale', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final vi = await AppLocalizations.delegate.load(const Locale('vi'));

    expect(languageDisplayName(en, 'vie'), 'Vietnamese');
    expect(languageDisplayName(vi, 'vie'), 'Tiếng Việt');
    expect(languageDisplayName(en, 'zxx'), 'No lyrics');
    expect(languageDisplayName(vi, 'mul'), 'Nhiều ngôn ngữ');
  });

  test('an unknown key shows its key upper-cased', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    expect(languageDisplayName(en, 'x-klingon'), 'X-KLINGON');
  });
}
