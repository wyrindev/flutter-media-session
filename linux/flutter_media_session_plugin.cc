#include "include/flutter_media_session/flutter_media_session_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <memory>
#include <string>
#include <unordered_set>

#include "mpris_player.h"

#define FLUTTER_MEDIA_SESSION_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_media_session_plugin_get_type(), \
                              FlutterMediaSessionPlugin))

struct _FlutterMediaSessionPlugin {
  GObject parent_instance;
  FlMethodChannel* method_channel;
  FlEventChannel* event_channel;
  std::unique_ptr<flutter_media_session::MprisPlayer> mpris_player;
  gboolean event_sink_active;
  guint screensaver_inhibit_cookie;
};

G_DEFINE_TYPE(FlutterMediaSessionPlugin,
              flutter_media_session_plugin,
              g_object_get_type())

static FlMethodResponse* activate(FlutterMediaSessionPlugin* self) {
  if (self->mpris_player) {
    self->mpris_player->Activate();
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static FlMethodResponse* deactivate(FlutterMediaSessionPlugin* self) {
  if (self->mpris_player) {
    self->mpris_player->Deactivate();
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static FlMethodResponse* update_metadata(FlutterMediaSessionPlugin* self,
                                        FlValue* args) {
  if (!self->mpris_player || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }

  GVariantBuilder builder;
  g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));

  // Track ID (Mandatory for MPRIS 2)
  g_variant_builder_add(&builder, "{sv}", "mpris:trackid",
                        g_variant_new_object_path("/org/mpris/MediaPlayer2/Track/1"));

  FlValue* title_val = fl_value_lookup_string(args, "title");
  if (title_val && fl_value_get_type(title_val) == FL_VALUE_TYPE_STRING) {
    g_variant_builder_add(&builder, "{sv}", "xesam:title",
                          g_variant_new_string(fl_value_get_string(title_val)));
  }

  FlValue* artist_val = fl_value_lookup_string(args, "artist");
  if (artist_val && fl_value_get_type(artist_val) == FL_VALUE_TYPE_STRING) {
    const gchar* artist_str = fl_value_get_string(artist_val);
    const gchar* artists[] = {artist_str, nullptr};
    g_variant_builder_add(&builder, "{sv}", "xesam:artist",
                          g_variant_new_strv(artists, 1));
  }

  FlValue* album_val = fl_value_lookup_string(args, "album");
  if (album_val && fl_value_get_type(album_val) == FL_VALUE_TYPE_STRING) {
    g_variant_builder_add(&builder, "{sv}", "xesam:album",
                          g_variant_new_string(fl_value_get_string(album_val)));
  }

  FlValue* album_artist_val = fl_value_lookup_string(args, "albumArtist");
  if (album_artist_val && fl_value_get_type(album_artist_val) == FL_VALUE_TYPE_STRING) {
    const gchar* album_artist_str = fl_value_get_string(album_artist_val);
    const gchar* album_artists[] = {album_artist_str, nullptr};
    g_variant_builder_add(&builder, "{sv}", "xesam:albumArtist",
                          g_variant_new_strv(album_artists, 1));
  }

  FlValue* duration_val = fl_value_lookup_string(args, "durationMs");
  if (duration_val && fl_value_get_type(duration_val) == FL_VALUE_TYPE_INT) {
    int64_t duration_us = fl_value_get_int(duration_val) * 1000;
    g_variant_builder_add(&builder, "{sv}", "mpris:length",
                          g_variant_new_int64(duration_us));
  }

  FlValue* artwork_val = fl_value_lookup_string(args, "artworkUri");
  if (artwork_val && fl_value_get_type(artwork_val) == FL_VALUE_TYPE_STRING) {
    g_variant_builder_add(&builder, "{sv}", "mpris:artUrl",
                          g_variant_new_string(fl_value_get_string(artwork_val)));
  }

  GVariant* metadata_dict = g_variant_builder_end(&builder);
  self->mpris_player->UpdateMetadata(metadata_dict);

  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static FlMethodResponse* update_playback_state(FlutterMediaSessionPlugin* self,
                                              FlValue* args) {
  if (!self->mpris_player || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }

  std::string status = "Stopped";
  FlValue* status_val = fl_value_lookup_string(args, "status");
  if (status_val && fl_value_get_type(status_val) == FL_VALUE_TYPE_STRING) {
    std::string s = fl_value_get_string(status_val);
    if (s == "playing") {
      status = "Playing";
    } else if (s == "paused") {
      status = "Paused";
    } else {
      status = "Stopped";
    }
  }

  int64_t position_ms = 0;
  FlValue* pos_val = fl_value_lookup_string(args, "positionMs");
  if (pos_val && fl_value_get_type(pos_val) == FL_VALUE_TYPE_INT) {
    position_ms = fl_value_get_int(pos_val);
  }

  double speed = 1.0;
  FlValue* speed_val = fl_value_lookup_string(args, "speed");
  if (speed_val && fl_value_get_type(speed_val) == FL_VALUE_TYPE_FLOAT) {
    speed = fl_value_get_float(speed_val);
  }

  std::string repeat_mode = "None";
  FlValue* repeat_val = fl_value_lookup_string(args, "repeatMode");
  if (repeat_val && fl_value_get_type(repeat_val) == FL_VALUE_TYPE_STRING) {
    std::string r = fl_value_get_string(repeat_val);
    if (r == "one") {
      repeat_mode = "Track";
    } else if (r == "all") {
      repeat_mode = "Playlist";
    } else {
      repeat_mode = "None";
    }
  }

  bool shuffle = false;
  FlValue* shuffle_val = fl_value_lookup_string(args, "shuffleModeEnabled");
  if (shuffle_val && fl_value_get_type(shuffle_val) == FL_VALUE_TYPE_BOOL) {
    shuffle = fl_value_get_bool(shuffle_val);
  }

  self->mpris_player->UpdatePlaybackState(status, position_ms, speed, repeat_mode, shuffle);

  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static FlMethodResponse* update_available_actions(FlutterMediaSessionPlugin* self,
                                                 FlValue* args) {
  if (!self->mpris_player) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }

  std::unordered_set<std::string> actions;
  if (args && fl_value_get_type(args) == FL_VALUE_TYPE_LIST) {
    size_t length = fl_value_get_length(args);
    for (size_t i = 0; i < length; ++i) {
      FlValue* item = fl_value_get_list_value(args, i);
      if (fl_value_get_type(item) == FL_VALUE_TYPE_STRING) {
        actions.insert(fl_value_get_string(item));
      }
    }
  }

  self->mpris_player->UpdateAvailableActions(actions);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static FlMethodResponse* set_background_keep_alive(FlutterMediaSessionPlugin* self,
                                                  FlValue* args) {
  gboolean enabled = FALSE;
  if (args && fl_value_get_type(args) == FL_VALUE_TYPE_BOOL) {
    enabled = fl_value_get_bool(args);
  }

  g_autoptr(GError) error = nullptr;
  g_autoptr(GDBusConnection) connection = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);

  if (connection && !error) {
    if (enabled && self->screensaver_inhibit_cookie == 0) {
      g_autoptr(GVariant) reply = g_dbus_connection_call_sync(
          connection,
          "org.freedesktop.ScreenSaver",
          "/org/freedesktop/ScreenSaver",
          "org.freedesktop.ScreenSaver",
          "Inhibit",
          g_variant_new("(ss)", "flutter_media_session", "Media playback in progress"),
          G_VARIANT_TYPE("(u)"),
          G_DBUS_CALL_FLAGS_NONE,
          -1,
          nullptr,
          nullptr);
      if (reply) {
        g_variant_get(reply, "(u)", &self->screensaver_inhibit_cookie);
      }
    } else if (!enabled && self->screensaver_inhibit_cookie != 0) {
      g_dbus_connection_call_sync(
          connection,
          "org.freedesktop.ScreenSaver",
          "/org/freedesktop/ScreenSaver",
          "org.freedesktop.ScreenSaver",
          "UnInhibit",
          g_variant_new("(u)", self->screensaver_inhibit_cookie),
          nullptr,
          G_DBUS_CALL_FLAGS_NONE,
          -1,
          nullptr,
          nullptr);
      self->screensaver_inhibit_cookie = 0;
    }
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static FlMethodResponse* set_windows_app_user_model_id(FlutterMediaSessionPlugin* self,
                                                       FlValue* args) {
  if (self->mpris_player && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    FlValue* id_val = fl_value_lookup_string(args, "id");
    if (id_val && fl_value_get_type(id_val) == FL_VALUE_TYPE_STRING) {
      self->mpris_player->SetDesktopEntry(fl_value_get_string(id_val));
    }
    FlValue* name_val = fl_value_lookup_string(args, "displayName");
    if (name_val && fl_value_get_type(name_val) == FL_VALUE_TYPE_STRING) {
      self->mpris_player->SetIdentity(fl_value_get_string(name_val));
    }
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static void flutter_media_session_plugin_handle_method_call(
    FlutterMediaSessionPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "activate") == 0) {
    response = activate(self);
  } else if (strcmp(method, "deactivate") == 0) {
    response = deactivate(self);
  } else if (strcmp(method, "updateMetadata") == 0) {
    response = update_metadata(self, args);
  } else if (strcmp(method, "updatePlaybackState") == 0) {
    response = update_playback_state(self, args);
  } else if (strcmp(method, "updateAvailableActions") == 0) {
    response = update_available_actions(self, args);
  } else if (strcmp(method, "setBackgroundKeepAlive") == 0) {
    response = set_background_keep_alive(self, args);
  } else if (strcmp(method, "setWindowsAppUserModelId") == 0 ||
             strcmp(method, "setAppId") == 0) {
    response = set_windows_app_user_model_id(self, args);
  } else if (strcmp(method, "setAutoHandleInterruptions") == 0 ||
             strcmp(method, "setHandlesInterruptions") == 0 ||
             strcmp(method, "setActionLayout") == 0 ||
             strcmp(method, "setSkipIntervals") == 0) {
    // Safe no-ops on Linux
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "requestNotificationPermission") == 0) {
    // Linux doesn't require runtime notification permission prompt for MPRIS
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static FlMethodErrorResponse* event_listen(FlEventChannel* channel,
                                          FlValue* args,
                                          gpointer user_data) {
  auto* self = FLUTTER_MEDIA_SESSION_PLUGIN(user_data);
  self->event_sink_active = TRUE;
  return nullptr;
}

static FlMethodErrorResponse* event_cancel(FlEventChannel* channel,
                                          FlValue* args,
                                          gpointer user_data) {
  auto* self = FLUTTER_MEDIA_SESSION_PLUGIN(user_data);
  self->event_sink_active = FALSE;
  return nullptr;
}

static void flutter_media_session_plugin_dispose(GObject* object) {
  FlutterMediaSessionPlugin* self = FLUTTER_MEDIA_SESSION_PLUGIN(object);

  if (self->screensaver_inhibit_cookie != 0) {
    g_autoptr(GError) error = nullptr;
    g_autoptr(GDBusConnection) connection = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
    if (connection && !error) {
      g_dbus_connection_call_sync(
          connection,
          "org.freedesktop.ScreenSaver",
          "/org/freedesktop/ScreenSaver",
          "org.freedesktop.ScreenSaver",
          "UnInhibit",
          g_variant_new("(u)", self->screensaver_inhibit_cookie),
          nullptr,
          G_DBUS_CALL_FLAGS_NONE,
          -1,
          nullptr,
          nullptr);
    }
    self->screensaver_inhibit_cookie = 0;
  }

  self->mpris_player.reset();

  if (self->method_channel) {
    g_clear_object(&self->method_channel);
  }
  if (self->event_channel) {
    g_clear_object(&self->event_channel);
  }

  G_OBJECT_CLASS(flutter_media_session_plugin_parent_class)->dispose(object);
}

static void flutter_media_session_plugin_class_init(
    FlutterMediaSessionPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_media_session_plugin_dispose;
}

static void flutter_media_session_plugin_init(FlutterMediaSessionPlugin* self) {
  self->event_sink_active = FALSE;
  self->mpris_player = std::make_unique<flutter_media_session::MprisPlayer>(
      [self](const std::string& action, int64_t seek_position_ms) {
        if (!self->event_sink_active || !self->event_channel) return;

        g_autoptr(FlValue) event = fl_value_new_map();
        fl_value_set_string_take(event, "action", fl_value_new_string(action.c_str()));
        if (seek_position_ms >= 0) {
          fl_value_set_string_take(event, "args", fl_value_new_int(seek_position_ms));
          fl_value_set_string_take(event, "positionMs", fl_value_new_int(seek_position_ms));
        }

        fl_event_channel_send(self->event_channel, event, nullptr, nullptr);
      });
}

void flutter_media_session_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  FlutterMediaSessionPlugin* plugin = FLUTTER_MEDIA_SESSION_PLUGIN(
      g_object_new(flutter_media_session_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  plugin->method_channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "flutter_media_session",
      FL_METHOD_CODEC(codec));

  fl_method_channel_set_method_call_handler(
      plugin->method_channel,
      [](FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
        flutter_media_session_plugin_handle_method_call(
            FLUTTER_MEDIA_SESSION_PLUGIN(user_data), method_call);
      },
      g_object_ref(plugin),
      g_object_unref);

  plugin->event_channel = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "flutter_media_session_events",
      FL_METHOD_CODEC(codec));

  fl_event_channel_set_stream_handlers(
      plugin->event_channel,
      event_listen,
      event_cancel,
      g_object_ref(plugin),
      g_object_unref);

  g_object_unref(plugin);
}
