#ifndef RUNNER_OPEN_FILES_H_
#define RUNNER_OPEN_FILES_H_

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>

// Hands the files to play (command line, "Open with") to Dart over a method
// channel. Dart side: lib/core/open_files/.
//
// Only the newest request counts: a request that arrives before Dart is ready
// replaces the one waiting, like Dart replaces a request still being read.
typedef struct _OpenFiles OpenFiles;

OpenFiles* open_files_new();
void open_files_free(OpenFiles* self);

// Call when a Flutter view (and so an engine) is created. Drops the channel
// of an earlier view and waits for the new Dart side to ask for pending files.
void open_files_attach(OpenFiles* self, FlBinaryMessenger* messenger);

// Keeps the native local files of [files] with a UTF-8 path and sends them to
// Dart, or holds them until Dart asks. A call with no usable file changes
// nothing.
void open_files_handle(OpenFiles* self, GFile** files, gint n_files);

// The files named in [arguments] (the program name first), as GFiles. A
// relative path means the folder of the process that was started. An argument
// that starts with `-` is an option, except after `--`. Free with
// g_ptr_array_unref.
GPtrArray* open_files_from_arguments(gchar** arguments);

#endif  // RUNNER_OPEN_FILES_H_
