#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

// athena/clipboard_image 的 channel 实例（生命周期与进程一致）。
static FlMethodChannel* clipboard_image_channel = NULL;

// 图片文件扩展名白名单（用于识别剪贴板中的图片文件）。
static gboolean is_image_extension(const gchar* ext) {
  static const gchar* k_image_extensions[] = {
      "png", "jpg", "jpeg", "gif", "webp", "bmp", "tif", "tiff", "heic",
      "heif", NULL};
  for (gint i = 0; k_image_extensions[i] != NULL; i++) {
    if (g_strcmp0(ext, k_image_extensions[i]) == 0) {
      return TRUE;
    }
  }
  return FALSE;
}

// 读取系统剪贴板中的图片：
// - {"base64": <PNG base64>}：剪贴板中是图片数据（如截图工具）
// - {"path": <文件路径>}：剪贴板中是图片文件（如文件管理器复制）
// - null：剪贴板中没有图片
static void clipboard_image_method_call_cb(FlMethodChannel*,
                                           FlMethodCall* method_call,
                                           gpointer) {
  if (g_strcmp0(fl_method_call_get_name(method_call), "readClipboardImage") !=
      0) {
    fl_method_call_respond(method_call,
                           FL_METHOD_RESPONSE(fl_method_not_implemented_response_new()),
                           NULL);
    return;
  }

  g_autoptr(FlMethodResponse) response = NULL;
  GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);

  // 1. 文件优先：文件管理器复制文件时剪贴板可能同时携带图标预览数据，
  //    此时应以文件本身为准，否则发送的是图标而不是图片内容。
  //    注意浏览器复制图片时也会带 text/uri-list（图片网页 URL，非 file://），
  //    只有 file:// 前缀的 URI 才算文件复制场景。
  gboolean has_file_uris = FALSE;
  gchar** uris = gtk_clipboard_wait_for_uris(clipboard);
  if (uris != NULL) {
    for (gint i = 0; uris[i] != NULL; i++) {
      if (!g_str_has_prefix(uris[i], "file://")) {
        continue;
      }
      has_file_uris = TRUE;
      g_autofree gchar* path = g_filename_from_uri(uris[i], NULL, NULL);
      if (path == NULL) {
        continue;
      }
      g_autofree gchar* ext = g_path_get_extension(path);
      if (ext == NULL || *ext == '\0') {
        continue;
      }
      // 去掉前导 "." 并转小写，空扩展名（结尾 "."）视为非图片
      g_autofree gchar* ext_lower = g_utf8_strdown(ext + 1, -1);
      if (ext_lower == NULL || *ext_lower == '\0') {
        continue;
      }
      if (!is_image_extension(ext_lower)) {
        continue;
      }
      // API 只接受 png/gif/webp：兼容格式直接给路径，其他转 PNG
      if (g_strcmp0(ext_lower, "png") == 0 || g_strcmp0(ext_lower, "gif") == 0 ||
          g_strcmp0(ext_lower, "webp") == 0) {
        g_autoptr(FlValue) map = fl_value_new_map();
        fl_value_set_string_take(map, "path", fl_value_new_string(path));
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(map));
        break;
      }
      g_autoptr(GdkPixbuf) pixbuf = gdk_pixbuf_new_from_file(path, NULL);
      if (pixbuf != NULL) {
        gchar* buffer = NULL;
        gsize buffer_size = 0;
        if (gdk_pixbuf_save_to_buffer(pixbuf, &buffer, &buffer_size, "png",
                                      NULL, NULL)) {
          g_autofree gchar* b64 =
              g_base64_encode((const guchar*)buffer, buffer_size);
          g_free(buffer);
          g_autoptr(FlValue) map = fl_value_new_map();
          fl_value_set_string_take(map, "base64", fl_value_new_string(b64));
          response = FL_METHOD_RESPONSE(fl_method_success_response_new(map));
          break;
        }
      }
    }
    g_strfreev(uris);
  }

  // 2. 剪贴板中的图片数据（截图等），统一转成 PNG；
  //    文件复制场景（含 file:// URI）中图标预览数据不作为图片内容。
  if (response == NULL && !has_file_uris &&
      gtk_clipboard_wait_is_image_available(clipboard)) {
    GdkPixbuf* pixbuf = gtk_clipboard_wait_for_image(clipboard);
    if (pixbuf != NULL) {
      gchar* buffer = NULL;
      gsize buffer_size = 0;
      if (gdk_pixbuf_save_to_buffer(pixbuf, &buffer, &buffer_size, "png", NULL,
                                    NULL)) {
        g_autofree gchar* b64 =
            g_base64_encode((const guchar*)buffer, buffer_size);
        g_free(buffer);
        g_autoptr(FlValue) map = fl_value_new_map();
        fl_value_set_string_take(map, "base64", fl_value_new_string(b64));
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(map));
      }
      g_object_unref(pixbuf);
    }
  }

  if (response == NULL) {
    response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }

  g_autoptr(GError) error = NULL;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to respond to readClipboardImage: %s", error->message);
  }
}

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
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
    gtk_header_bar_set_title(header_bar, "athena");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "athena");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // 注册 athena/clipboard_image channel（读取剪贴板图片）
  FlEngine* engine = fl_view_get_engine(view);
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  clipboard_image_channel = fl_method_channel_new(
      messenger, "athena/clipboard_image", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(clipboard_image_channel,
                                            clipboard_image_method_call_cb,
                                            NULL, NULL);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
