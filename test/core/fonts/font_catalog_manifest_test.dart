import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/fonts/font_catalog_manifest.dart';

void main() {
  group('catalogFontsManifest', () {
    test('contains exactly 7 catalog fonts', () {
      expect(catalogFontsManifest.length, 7);
    });

    test('all font ids are unique and kebab-case', () {
      final ids = catalogFontsManifest.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(RegExp(r'^[a-z0-9-]+$').hasMatch(id), isTrue, reason: id);
      }
    });

    test('downloadUrl matches release asset URL format', () {
      for (final item in catalogFontsManifest) {
        expect(
          item.downloadUrl,
          'https://github.com/kanaru313/kanaru/releases/download/fonts-v1/${item.filename}',
        );
        expect(item.filename.endsWith('.zip'), isTrue);
      }
    });

    test('formattedSize formats size in KB', () {
      for (final item in catalogFontsManifest) {
        expect(item.formattedSize, endsWith(' KB'));
        final expectedKb = (item.sizeBytes / 1024).round();
        expect(item.formattedSize, '$expectedKb KB');
      }
    });

    test('sha256 digests are 64 lowercase hexadecimal characters', () {
      final hexRegex = RegExp(r'^[0-9a-f]{64}$');
      for (final item in catalogFontsManifest) {
        expect(hexRegex.hasMatch(item.sha256), isTrue, reason: item.id);
      }
    });

    test('categories are valid font categories', () {
      const allowedCategories = {'sans-serif', 'serif', 'monospace'};
      for (final item in catalogFontsManifest) {
        expect(allowedCategories.contains(item.category), isTrue, reason: item.id);
      }
    });

    test('preview SVG asset path starts with assets/font_previews/', () {
      for (final item in catalogFontsManifest) {
        expect(
          item.previewSvgAsset.startsWith('assets/font_previews/'),
          isTrue,
          reason: item.id,
        );
        expect(item.previewSvgAsset.endsWith('.svg'), isTrue);
      }
    });
  });
}
