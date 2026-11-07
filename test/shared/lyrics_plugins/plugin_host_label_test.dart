import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/lyrics_plugins/plugin_host_label.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('a wildcard host reads as any subdomain of its base', () {
    expect(
      pluginHostLabel(l10n, '*.googlevideo.com'),
      l10n.pluginInfoHostAnySubdomain('googlevideo.com'),
    );
    expect(
      pluginHostLabel(lookupAppLocalizations(const Locale('vi')), '*.x.com'),
      'Mọi tên miền con của x.com',
    );
  });

  test('a plain host is shown as it is', () {
    expect(pluginHostLabel(l10n, 'api.example.com'), 'api.example.com');
  });
}
