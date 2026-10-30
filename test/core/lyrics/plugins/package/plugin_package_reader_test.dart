import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_reader.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';

import 'package_test_helpers.dart';

Future<PluginPackage> accept(
  Uint8List zip, {
  FakePluginRuntime? runtime,
}) async {
  final result = await PluginPackageReader(runtime ?? FakePluginRuntime())
      .read(zip);
  expect(result, isA<PluginPackageAccepted>());
  return (result as PluginPackageAccepted).package;
}

void main() {
  test('accepts a valid package and returns every kept file', () async {
    final runtime = FakePluginRuntime();
    final package = await accept(
      validZip(extra: {'src/util.js': 'var a = 1;', 'readme.md': 'ignored'}),
      runtime: runtime,
    );
    expect(package.manifest.name, 'Demo');
    expect(package.files.keys, ['lyrics.js', 'search.js', 'util.js']);
    expect(package.icon, isNull);
    // Every kept script is checked, ignored entries are not.
    expect(
      runtime.checked,
      unorderedEquals(['lyrics.js', 'search.js', 'util.js']),
    );
  });

  test('accepts a zipped folder (single top-level folder stripped)', () async {
    final package = await accept(validZip(prefix: 'netease/'));
    expect(package.files.keys, ['lyrics.js', 'search.js']);
  });

  test('strips a byte order mark from scripts', () async {
    final package = await accept(validZip(extra: {'src/search.js': '﻿var a;'}));
    expect(package.files['search.js'], 'var a;');
  });

  test('a script that is not UTF-8 is a scriptError naming the file', () async {
    final problem = await readProblem(
      validZip(
        extra: {
          'src/search.js': Uint8List.fromList([0xff, 0xfe, 0x41]),
        },
      ),
    );
    expect(problem.kind, PluginPackageProblemKind.scriptError);
    expect(problem.detail, 'search.js');
  });

  test('a missing script file is missingScript', () async {
    final manifest = validManifest();
    (manifest['script'] as Map)['lyrics'] = 'other.js';
    final problem = await readProblem(validZip(manifest: manifest));
    expect(problem.kind, PluginPackageProblemKind.missingScript);
    expect(problem.detail, 'other.js');
  });

  test('a syntax error is a scriptError with file, line and message', () async {
    final problem = await readProblem(
      validZip(),
      runtime: FakePluginRuntime(
        problems: {
          'lyrics.js': const PluginScriptProblem(
            message: 'unexpected token',
            line: 7,
          ),
        },
      ),
    );
    expect(problem.kind, PluginPackageProblemKind.scriptError);
    expect(problem.detail, 'lyrics.js');
    expect(problem.line, 7);
    expect(problem.message, 'unexpected token');
  });

  test('a utility script with a syntax error rejects the package', () async {
    final problem = await readProblem(
      validZip(extra: {'src/util.js': 'x'}),
      runtime: FakePluginRuntime(
        problems: {'util.js': const PluginScriptProblem(message: 'bad')},
      ),
    );
    expect(problem.detail, 'util.js');
    expect(problem.line, isNull);
  });

  test('a runtime that cannot check never accepts the package', () async {
    final problem = await readProblem(
      validZip(),
      runtime: FakePluginRuntime(throwOnCheck: true),
    );
    expect(problem.kind, PluginPackageProblemKind.checkUnavailable);
  });

  test('zip and manifest problems surface as rejected results', () async {
    expect(
      (await readProblem(Uint8List.fromList([1, 2, 3]))).kind,
      PluginPackageProblemKind.notZip,
    );
    final manifest = validManifest();
    (manifest['metadata'] as Map)['hosts'] = ['127.0.0.1'];
    final problem = await readProblem(validZip(manifest: manifest));
    expect(problem.kind, PluginPackageProblemKind.badHost);
    expect(problem.detail, '127.0.0.1');
  });

  test('no script is checked when the manifest is refused', () async {
    final runtime = FakePluginRuntime();
    final manifest = validManifest();
    (manifest['metadata'] as Map)['apiVersion'] = 2;
    final problem = await readProblem(
      validZip(manifest: manifest),
      runtime: runtime,
    );
    expect(problem.kind, PluginPackageProblemKind.needsNewerApp);
    expect(runtime.checked, isEmpty);
  });

  group('icon', () {
    test('a valid icon is kept', () async {
      final icon = pngHeader(64, 64);
      final package = await accept(validZip(extra: {'icon.png': icon}));
      expect(package.icon, icon);
    });

    test('icon at the 256 x 256 edge is kept', () async {
      final package = await accept(
        validZip(extra: {'icon.png': pngHeader(256, 256)}),
      );
      expect(package.icon, isNotNull);
    });

    for (final entry in {
      'not a PNG': Uint8List.fromList(
        utf8.encode('GIF89a plus padding to 30 bytes'),
      ),
      'too big a side': pngHeader(257, 16),
      'zero size': pngHeader(0, 16),
      'truncated': Uint8List.fromList([0x89, 0x50, 0x4e]),
      'over 64 KiB': Uint8List(64 * 1024 + 1)..setAll(0, pngHeader(16, 16)),
    }.entries) {
      test(
        'a bad icon (${entry.key}) is dropped and the install goes on',
        () async {
          final package = await accept(
            validZip(extra: {'icon.png': entry.value}),
          );
          expect(package.icon, isNull);
          expect(package.files, isNotEmpty);
        },
      );
    }
  });
}
