import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_names.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/l10n/app_localizations_vi.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_source_name_text.dart';

void main() {
  final AppLocalizations en = AppLocalizationsEn();
  final AppLocalizations vi = AppLocalizationsVi();

  String text(
    AppLocalizations l10n,
    Map<String, LyricsSourceName> names,
    String id,
  ) => lyricsSourceNameText(l10n, names, id);

  test('a plain source keeps its name', () {
    final names = {
      'lrclib': const LyricsSourceName(displayName: 'LRCLIB'),
      'plugin-a': const LyricsSourceName(displayName: 'NetEase', author: 'x'),
    };
    expect(text(en, names, 'lrclib'), 'LRCLIB');
    expect(text(en, names, 'plugin-a'), 'NetEase');
  });

  test('an unknown id is shown as it is', () {
    expect(text(en, const {}, 'gone-id'), 'gone-id');
  });

  test('a removed plugin gets the removed mark, in both languages', () {
    final names = {
      'plugin-a': const LyricsSourceName(displayName: 'NetEase', removed: true),
    };
    expect(text(en, names, 'plugin-a'), 'NetEase (removed)');
    expect(text(vi, names, 'plugin-a'), 'NetEase (đã gỡ)');
  });

  test('two sources that share a name get their authors', () {
    final names = {
      'plugin-a': const LyricsSourceName(
        displayName: 'NetEase',
        author: 'hieu05',
      ),
      'plugin-b': const LyricsSourceName(
        displayName: 'netease',
        author: 'other-dev',
      ),
    };
    expect(text(en, names, 'plugin-a'), 'NetEase · hieu05');
    expect(text(en, names, 'plugin-b'), 'netease · other-dev');
  });

  test('a clash without an author keeps the bare name', () {
    final names = {
      'plugin-a': const LyricsSourceName(displayName: 'NetEase'),
      'plugin-b': const LyricsSourceName(displayName: 'NetEase', author: 'z'),
    };
    expect(text(en, names, 'plugin-a'), 'NetEase');
    expect(text(en, names, 'plugin-b'), 'NetEase · z');
  });

  test('a removed plugin and a running one do not clash', () {
    final names = {
      'plugin-a': const LyricsSourceName(displayName: 'NetEase', author: 'a'),
      'plugin-b': const LyricsSourceName(
        displayName: 'NetEase',
        author: 'b',
        removed: true,
      ),
    };
    expect(text(vi, names, 'plugin-b'), 'NetEase (đã gỡ)');
    expect(text(vi, names, 'plugin-a'), 'NetEase');
  });

  test('two removed plugins that share a name show author and mark', () {
    final names = {
      'plugin-a': const LyricsSourceName(
        displayName: 'NetEase',
        author: 'a',
        removed: true,
      ),
      'plugin-b': const LyricsSourceName(
        displayName: 'NetEase',
        author: 'b',
        removed: true,
      ),
    };
    expect(text(vi, names, 'plugin-b'), 'NetEase · b (đã gỡ)');
  });
}
