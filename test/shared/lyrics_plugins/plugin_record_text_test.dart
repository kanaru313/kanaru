import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/lyrics_plugins/plugin_record_text.dart';

import '../../features/lyrics_plugin_store/store_test_harness.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('sizes use bytes, KB, then MB', () {
    expect(pluginSizeText(l10n, 0), l10n.settingsUnitBytes(0));
    expect(pluginSizeText(l10n, 1023), l10n.settingsUnitBytes(1023));
    expect(pluginSizeText(l10n, 3200), l10n.settingsUnitKb(3));
    expect(pluginSizeText(l10n, 2 * 1024 * 1024), l10n.settingsUnitMb(2));
  });

  test('the byline joins the author and the version', () {
    expect(
      pluginByline(l10n, recordOf('a', author: 'Mai', version: 4)),
      '${l10n.lyricsSourceAuthor('Mai')} · v4',
    );
    expect(
      pluginByline(l10n, recordOf('a', version: 2)),
      '${l10n.lyricsSourceUnknownAuthor} · v2',
    );
  });
}
