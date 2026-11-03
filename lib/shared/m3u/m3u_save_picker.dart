import 'package:file_selector/file_selector.dart' as picker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the system save dialog starting at [suggestedName]; null when
/// cancelled. The dialog does not ask before overwriting: callers do.
typedef M3uSavePicker = Future<String?> Function(String suggestedName);

/// GTK matches file patterns case-sensitively, so upper case extensions are
/// listed too; the MIME types catch files named otherwise.
const m3uTypeGroup = picker.XTypeGroup(
  label: 'M3U',
  extensions: ['m3u', 'm3u8', 'M3U', 'M3U8'],
  mimeTypes: [
    'audio/x-mpegurl',
    'audio/mpegurl',
    'application/vnd.apple.mpegurl',
  ],
);

/// The M3U save dialog. Tests override it.
final m3uSavePickerProvider = Provider<M3uSavePicker>(
  (ref) =>
      (suggestedName) async => (await picker.getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const [m3uTypeGroup],
      ))?.path,
);
