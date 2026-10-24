import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/folders/hidden_folder_page_provider.dart';

void main() {
  test('accepts the paths the app writes', () {
    expect(isCleanFolderPath('/'), isTrue);
    expect(isCleanFolderPath('/m'), isTrue);
    expect(isCleanFolderPath('/m/.secret/a b'), isTrue);
    expect(isCleanFolderPath('/m/..hidden/.x'), isTrue);
  });

  test(
    'rejects relative, dotted, empty-part, trailing-slash and NUL paths',
    () {
      for (final path in [
        '',
        'm/a',
        '/m/',
        '/m//a',
        '/m/./a',
        '/m/../a',
        '/..',
        '/m/a\u0000',
        '\u0000',
      ]) {
        expect(isCleanFolderPath(path), isFalse, reason: path);
      }
    },
  );
}
