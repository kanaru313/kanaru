#include "open_files.h"

// Channel for files to open; Dart side: lib/core/open_files/.
static const char* kOpenFilesChannel = "io.github.kanaru313.kanaru/open_files";

// Most files one request carries, as on the Dart side. Bounds what a caller
// of the D-Bus Open method can make this process copy and queue.
static const guint kMaxFilesPerRequest = 1000;

struct _OpenFiles {
  // Method channel to Dart, created with the view.
  FlMethodChannel* channel;
  // Dart has answered takePendingFiles and listens for openFiles.
  gboolean dart_ready;
  // The latest request (native paths) that arrived before Dart asked for it.
  // Delivered by the takePendingFiles call, then requests are sent directly.
  GPtrArray* pending;
};

OpenFiles* open_files_new() { return g_new0(OpenFiles, 1); }

void open_files_free(OpenFiles* self) {
  if (self == nullptr) return;
  g_clear_object(&self->channel);
  g_clear_pointer(&self->pending, g_ptr_array_unref);
  g_free(self);
}

static FlValue* paths_to_list(GPtrArray* paths) {
  FlValue* list = fl_value_new_list();
  for (guint i = 0; i < paths->len; i++) {
    fl_value_append_take(
        list, fl_value_new_string(static_cast<const char*>(paths->pdata[i])));
  }
  return list;
}

// Answers the calls Dart makes on the channel.
static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  OpenFiles* self = static_cast<OpenFiles*>(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(fl_method_call_get_name(method_call), "takePendingFiles") ==
      0) {
    // Dart has set its openFiles handler before asking, so from here on files
    // go straight to it. Both steps run on the main thread, in this call.
    g_autoptr(FlValue) list = self->pending != nullptr
                                  ? paths_to_list(self->pending)
                                  : fl_value_new_list();
    g_clear_pointer(&self->pending, g_ptr_array_unref);
    self->dart_ready = TRUE;
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(list));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to answer %s: %s", fl_method_call_get_name(method_call),
              error->message);
  }
}

void open_files_attach(OpenFiles* self, FlBinaryMessenger* messenger) {
  // A new engine has not set its handler yet, so a request sent now would be
  // lost. Anything still pending stays for the new Dart side.
  g_clear_object(&self->channel);
  self->dart_ready = FALSE;

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->channel = fl_method_channel_new(messenger, kOpenFilesChannel,
                                        FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->channel, method_call_cb, self,
                                            nullptr);
}

void open_files_handle(OpenFiles* self, GFile** files, gint n_files) {
  // Only plain local paths go on; the player opens whatever string it gets.
  g_autoptr(GPtrArray) paths = g_ptr_array_new_with_free_func(g_free);
  guint skipped = 0;
  gint i = 0;
  for (; i < n_files && paths->len < kMaxFilesPerRequest; i++) {
    g_autofree gchar* path =
        g_file_is_native(files[i]) ? g_file_get_path(files[i]) : nullptr;
    if (path == nullptr || !g_utf8_validate(path, -1, nullptr)) {
      skipped++;
      continue;
    }
    g_ptr_array_add(paths, g_steal_pointer(&path));
  }
  // Names are not logged: they are the user's files.
  if (skipped > 0) {
    g_message("Skipped %u file(s) that are not local or have no UTF-8 path.",
              skipped);
  }
  if (i < n_files) {
    g_message("Opening only the first %u of %d files.", kMaxFilesPerRequest,
              n_files);
  }
  if (paths->len == 0) return;

  if (self->dart_ready && self->channel != nullptr) {
    g_autoptr(FlValue) list = paths_to_list(paths);
    fl_method_channel_invoke_method(self->channel, "openFiles", list, nullptr,
                                    nullptr, nullptr);
  } else {
    g_clear_pointer(&self->pending, g_ptr_array_unref);
    self->pending = static_cast<GPtrArray*>(g_steal_pointer(&paths));
  }
}

GPtrArray* open_files_from_arguments(gchar** arguments) {
  GPtrArray* files = g_ptr_array_new_with_free_func(g_object_unref);
  gboolean options_ended = FALSE;
  guint ignored = 0;
  for (gchar** arg = arguments + 1; *arg != nullptr; arg++) {
    if (!options_ended && g_strcmp0(*arg, "--") == 0) {
      options_ended = TRUE;
    } else if ((*arg)[0] == '\0') {
      continue;
    } else if (!options_ended && (*arg)[0] == '-') {
      ignored++;
    } else {
      g_ptr_array_add(files, g_file_new_for_commandline_arg(*arg));
    }
  }
  if (ignored > 0) {
    g_message(
        "Ignored %u argument(s) starting with '-'. Put them after '--' or "
        "write ./name to open such a file.",
        ignored);
  }
  return files;
}
