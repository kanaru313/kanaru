import 'package:file_selector/file_selector.dart' as picker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the system folder picker; completes with `null` when the user
/// cancels.
typedef DirectoryPicker = Future<String?> Function();

/// The folder picker used by the library screens. Tests override it, since
/// the router builds screens without constructor arguments.
final directoryPickerProvider = Provider<DirectoryPicker>(
  (ref) =>
      () => picker.getDirectoryPath(),
);
