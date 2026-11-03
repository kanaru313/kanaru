import 'package:file_selector/file_selector.dart' as picker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/m3u/m3u_save_picker.dart' show m3uTypeGroup;

/// Opens the system file picker for an M3U file; null when cancelled.
/// [allFilesLabel] names the catch-all filter.
typedef M3uOpenPicker = Future<String?> Function(String allFilesLabel);

/// The M3U open picker. Tests override it.
final m3uOpenPickerProvider = Provider<M3uOpenPicker>(
  (ref) =>
      (allFilesLabel) async => (await picker.openFile(
        acceptedTypeGroups: [
          m3uTypeGroup,
          picker.XTypeGroup(label: allFilesLabel),
        ],
      ))?.path,
);
