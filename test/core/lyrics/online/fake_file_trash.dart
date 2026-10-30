import 'dart:io';

import 'package:kanaru/core/native/file_trash.dart';

/// A trash that moves files into [folder] (a scratch folder of the test), or
/// answers a scripted [results] queue without touching anything.
class FakeFileTrash implements FileTrash {
  FakeFileTrash(this.folder);

  final String folder;

  /// Paths asked for, in order.
  final calls = <String>[];

  /// Answers to give, one per call, before falling back on really moving the
  /// file. A scripted `trashed` still moves it.
  final results = <TrashResult>[];

  /// Runs after each call that moved the file (to make one reappear, say).
  void Function(String path)? afterTrashed;

  @override
  Future<TrashResult> trash(String path) async {
    calls.add(path);
    final scripted = results.isEmpty ? null : results.removeAt(0);
    if (scripted != null && scripted != TrashResult.trashed) return scripted;
    Directory(folder).createSync(recursive: true);
    try {
      FileSystemEntity.typeSync(path, followLinks: false) ==
              FileSystemEntityType.link
          ? Link(path).renameSync('$folder/${calls.length}')
          : File(path).renameSync('$folder/${calls.length}');
    } on FileSystemException {
      return TrashResult.notFound;
    }
    afterTrashed?.call(path);
    return TrashResult.trashed;
  }
}
