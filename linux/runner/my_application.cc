#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"
#include "open_files.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  // The window has been shown: by the first Flutter frame or by the fallback
  // timer. A relaunch only presents a window that is shown.
  gboolean shown;
  // Id of the first-frame fallback timer, 0 when none is pending.
  guint fallback_source;
  // Files from the command line and "Open with", on their way to Dart.
  OpenFiles* open_files;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  self->shown = TRUE;
  g_clear_handle_id(&self->fallback_source, g_source_remove);
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// How long to wait for the first frame before showing the window anyway.
// Longer than the library database open timeout (10 s), so a slow open does
// not show a black window; short enough that a failed startup is not a
// hidden process nobody can reach.
static const guint kFirstFrameFallbackSeconds = 15;

// Shows the window if no frame arrived in time. Runs once. The application
// outlives its windows, so it is safe user data; the window is looked up and
// may already be gone.
static gboolean show_window_fallback(gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->fallback_source = 0;
  GList* windows = gtk_application_get_windows(GTK_APPLICATION(self));
  if (!self->shown && windows != nullptr) {
    g_warning("No Flutter frame after %u s; showing the window anyway.",
              kFirstFrameFallbackSeconds);
    self->shown = TRUE;
    gtk_widget_show(GTK_WIDGET(windows->data));
  }
  return G_SOURCE_REMOVE;
}

// Brings the existing window forward, if there is one. A second launch (or
// the primary's own re-activation) reuses the window. Before the first frame
// the window is still hidden and first_frame_cb shows it; presenting it now
// would flash a black window. Once the fallback timer has shown it, it is
// presented like any other. Returns whether a window exists.
static gboolean present_window(MyApplication* self) {
  GList* windows = gtk_application_get_windows(GTK_APPLICATION(self));
  if (windows == nullptr) return FALSE;
  GtkWindow* existing = GTK_WINDOW(windows->data);
  if (self->shown || gtk_widget_get_visible(GTK_WIDGET(existing))) {
    gtk_window_deiconify(existing);
    gtk_window_present(existing);
  }
  return TRUE;
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  if (present_window(self)) return;

  // A new window starts hidden with a new engine; nothing of an earlier one
  // applies (a stale timer would show the new window before its first frame).
  self->shown = FALSE;
  g_clear_handle_id(&self->fallback_source, g_source_remove);

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Kanaru");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Kanaru");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  // Smallest window the layout supports, matching setUpDesktopWindow() in
  // lib/app/shell/window/desktop_window.dart. GTK reports the view's size
  // request to the compositor as the window's minimum size; the hints
  // window_manager sets on the GdkWindow get replaced by GTK's own.
  gtk_widget_set_size_request(GTK_WIDGET(view), 480, 720);
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  // If startup never produces a frame the process would stay hidden forever.
  // The first frame or dispose removes the timer.
  self->fallback_source = g_timeout_add_seconds(
      kFirstFrameFallbackSeconds, show_window_fallback, self);

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  open_files_attach(self->open_files,
                    fl_engine_get_binary_messenger(fl_view_get_engine(view)));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::open. Runs in the primary instance, for the files
// of its own command line and for those a second launch sent over D-Bus.
static void my_application_open(GApplication* application, GFile** files,
                                gint n_files, const gchar* hint) {
  MyApplication* self = MY_APPLICATION(application);

  // First launch with files: the view and the channel do not exist yet.
  if (gtk_application_get_windows(GTK_APPLICATION(application)) == nullptr) {
    my_application_activate(application);
  }

  open_files_handle(self->open_files, files, n_files);
  present_window(self);
}

// Hands the command line's files to the primary instance (this one, or the
// one that owns the application ID, over D-Bus); with no files, activates it.
static void open_or_activate(GApplication* application, gchar** arguments) {
  g_autoptr(GPtrArray) files = open_files_from_arguments(arguments);
  if (files->len > 0) {
    g_application_open(application, reinterpret_cast<GFile**>(files->pdata),
                       files->len, "");
  } else {
    g_application_activate(application);
  }
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  // Another instance owns the application ID: ask it to open the files and
  // show its window, then exit without creating a Flutter engine. Only the
  // files cross over; other arguments are dropped here.
  if (g_application_get_is_remote(application)) {
    g_message("Kanaru is already running; activating it.");
    open_or_activate(application, *arguments);
    *exit_status = 0;
    return TRUE;
  }

  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  open_or_activate(application, *arguments);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_handle_id(&self->fallback_source, g_source_remove);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_pointer(&self->open_files, open_files_free);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->open = my_application_open;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->open_files = open_files_new();
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

#ifndef NDEBUG
  // Debug: `flutter run` must start next to an installed instance.
  GApplicationFlags flags = static_cast<GApplicationFlags>(
      G_APPLICATION_NON_UNIQUE | G_APPLICATION_HANDLES_OPEN);
#else
  // Profile/Release: one instance per session, a second launch opens its
  // files in it and activates it.
  GApplicationFlags flags = G_APPLICATION_HANDLES_OPEN;
#endif

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     flags, nullptr));
}
