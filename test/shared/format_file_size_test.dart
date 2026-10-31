import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/shared/format_file_size.dart';

void main() {
  final l10n = AppLocalizationsEn();
  String f(int bytes) => formatFileSize(l10n, bytes);

  test('bytes, KB, MB', () {
    expect(f(512), '512 B');
    expect(f(2048), '2 KB');
    expect(f(5 * 1048576 + 300 * 1024), '5.3 MB');
  });

  test('never reads 1024 KB', () {
    expect(f(1048575), '1 MB');
    expect(f(1048576), '1 MB');
  });

  test('gigabytes', () {
    expect(f(1073741823), '1 GB');
    expect(f(1073741824), '1 GB');
    expect(f(3 * 1073741824 + 536870912), '3.5 GB');
  });
}
