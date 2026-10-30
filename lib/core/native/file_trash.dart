import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('file_trash');

/// What [FileTrash.trash] did.
enum TrashResult {
  /// The file is in the trash.
  trashed,

  /// There was no such file.
  notFound,

  /// The disk has no trash (a system mount, a mount marked "no trash"), or
  /// GLib could not be loaded.
  unsupported,

  /// The call took longer than the cap; the file may still be moved later.
  timedOut,

  /// Any other refusal (permissions, a vanished mount).
  failed,
}

/// Moves a file to the desktop trash. Never deletes: on any failure the file
/// stays where it is.
abstract interface class FileTrash {
  Future<TrashResult> trash(String path);
}

/// The app's trash; tests replace it.
final fileTrashProvider = Provider<FileTrash>((ref) => GioFileTrash());

/// How long a trash call is waited for, as long as a tag read.
const trashTimeout = Duration(seconds: 10);

/// [FileTrash] through GLib's `g_file_trash` (freedesktop trash spec: the
/// home trash under `$XDG_DATA_HOME`, `<mount>/.Trash-<uid>` on other disks).
///
/// The call is synchronous and a dead mount can block it, so it runs in an
/// isolate and is waited for at most [timeout]; the isolate may still finish
/// after that.
class GioFileTrash implements FileTrash {
  GioFileTrash({
    this.timeout = trashTimeout,
    @visibleForTesting Future<TrashResult> Function(String path)? run,
  }) : _run = run ?? ((path) => Isolate.run(() => trashWithGio(path)));

  final Duration timeout;
  final Future<TrashResult> Function(String path) _run;

  @override
  Future<TrashResult> trash(String path) async {
    try {
      return await _run(path).timeout(timeout);
    } on TimeoutException {
      _log.warning('Moving a file to the trash timed out');
      return TrashResult.timedOut;
    } on Object catch (error) {
      // Only the type: the message may carry the path.
      _log.warning('Moving a file to the trash failed (${error.runtimeType})');
      return TrashResult.failed;
    }
  }
}

/// The three `GError` fields that are read; the struct is never allocated
/// here, only read through the pointer GLib hands back.
final class _GError extends Struct {
  @Uint32()
  external int domain;

  @Int32()
  external int code;

  external Pointer<Utf8> message;
}

const _gIoErrorNotFound = 1;
const _gIoErrorNotSupported = 15;

typedef _NewForPathC = Pointer<Void> Function(Pointer<Utf8>);
typedef _NewForPath = Pointer<Void> Function(Pointer<Utf8>);
typedef _TrashC = Int32 Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Pointer<_GError>>,
);
typedef _Trash = int Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Pointer<_GError>>,
);
typedef _UnrefC = Void Function(Pointer<Void>);
typedef _Unref = void Function(Pointer<Void>);
typedef _QuarkC = Uint32 Function();
typedef _Quark = int Function();
typedef _ErrorFreeC = Void Function(Pointer<_GError>);
typedef _ErrorFree = void Function(Pointer<_GError>);

/// Opens the library that has GLib's symbols: the running process (the
/// Linux runner links GLib), else `libgio-2.0.so.0`.
typedef GioLoaders = List<DynamicLibrary Function()>;

final GioLoaders _defaultLoaders = [
  DynamicLibrary.process,
  () => DynamicLibrary.open('libgio-2.0.so.0'),
];

/// Moves [path] to the trash with GLib. Blocks; call it off the UI isolate.
/// Reads the error code only, never the message, and frees every native
/// allocation. [loaders] is replaced by tests.
@visibleForTesting
TrashResult trashWithGio(String path, {GioLoaders? loaders}) {
  final lib = _openGio(loaders ?? _defaultLoaders);
  if (lib == null) return TrashResult.unsupported;
  final _NewForPath newForPath;
  final _Trash trash;
  final _Unref unref;
  final _Quark quark;
  final _ErrorFree errorFree;
  try {
    newForPath = lib.lookupFunction<_NewForPathC, _NewForPath>(
      'g_file_new_for_path',
    );
    trash = lib.lookupFunction<_TrashC, _Trash>('g_file_trash');
    unref = lib.lookupFunction<_UnrefC, _Unref>('g_object_unref');
    quark = lib.lookupFunction<_QuarkC, _Quark>('g_io_error_quark');
    errorFree = lib.lookupFunction<_ErrorFreeC, _ErrorFree>('g_error_free');
  } on ArgumentError {
    return TrashResult.unsupported;
  }
  final cPath = path.toNativeUtf8(allocator: calloc);
  final errorSlot = calloc<Pointer<_GError>>();
  Pointer<Void> file = nullptr;
  try {
    file = newForPath(cPath);
    if (file == nullptr) return TrashResult.failed;
    final ok = trash(file, nullptr, errorSlot) != 0;
    final error = errorSlot.value;
    if (ok) {
      if (error != nullptr) errorFree(error);
      return TrashResult.trashed;
    }
    if (error == nullptr) return TrashResult.failed;
    try {
      final inIoDomain = error.ref.domain == quark();
      final code = error.ref.code;
      if (inIoDomain && code == _gIoErrorNotFound) return TrashResult.notFound;
      if (inIoDomain && code == _gIoErrorNotSupported) {
        return TrashResult.unsupported;
      }
      return TrashResult.failed;
    } finally {
      errorFree(error);
    }
  } finally {
    if (file != nullptr) unref(file);
    calloc.free(errorSlot);
    calloc.free(cPath);
  }
}

/// The first loader whose library has `g_file_trash`; `null` when none does.
DynamicLibrary? _openGio(GioLoaders loaders) {
  for (final load in loaders) {
    try {
      final lib = load();
      if (lib.providesSymbol('g_file_trash')) return lib;
    } on Object {
      // This loader cannot supply GLib; try the next one.
    }
  }
  return null;
}
