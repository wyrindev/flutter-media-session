#include "mpris_player.h"

#include <iostream>

namespace flutter_media_session {

namespace {

const char* kMprisIntrospectionXml =
    "<node>"
    "  <interface name='org.mpris.MediaPlayer2'>"
    "    <method name='Raise'/>"
    "    <method name='Quit'/>"
    "    <property name='CanQuit' type='b' access='read'/>"
    "    <property name='CanRaise' type='b' access='read'/>"
    "    <property name='HasTrackList' type='b' access='read'/>"
    "    <property name='Identity' type='s' access='read'/>"
    "    <property name='DesktopEntry' type='s' access='read'/>"
    "    <property name='SupportedUriSchemes' type='as' access='read'/>"
    "    <property name='SupportedMimeTypes' type='as' access='read'/>"
    "  </interface>"
    "  <interface name='org.mpris.MediaPlayer2.Player'>"
    "    <method name='Next'/>"
    "    <method name='Previous'/>"
    "    <method name='Pause'/>"
    "    <method name='PlayPause'/>"
    "    <method name='Stop'/>"
    "    <method name='Play'/>"
    "    <method name='Seek'>"
    "      <arg direction='in' name='Offset' type='x'/>"
    "    </method>"
    "    <method name='SetPosition'>"
    "      <arg direction='in' name='TrackId' type='o'/>"
    "      <arg direction='in' name='Position' type='x'/>"
    "    </method>"
    "    <method name='OpenUri'>"
    "      <arg direction='in' name='Uri' type='s'/>"
    "    </method>"
    "    <signal name='Seeked'>"
    "      <arg name='Position' type='x'/>"
    "    </signal>"
    "    <property name='PlaybackStatus' type='s' access='read'/>"
    "    <property name='LoopStatus' type='s' access='readwrite'/>"
    "    <property name='Rate' type='d' access='readwrite'/>"
    "    <property name='Shuffle' type='b' access='readwrite'/>"
    "    <property name='Metadata' type='a{sv}' access='read'/>"
    "    <property name='Volume' type='d' access='readwrite'/>"
    "    <property name='Position' type='x' access='read'/>"
    "    <property name='MinimumRate' type='d' access='read'/>"
    "    <property name='MaximumRate' type='d' access='read'/>"
    "    <property name='CanControl' type='b' access='read'/>"
    "    <property name='CanPlay' type='b' access='read'/>"
    "    <property name='CanPause' type='b' access='read'/>"
    "    <property name='CanSeek' type='b' access='read'/>"
    "    <property name='CanGoNext' type='b' access='read'/>"
    "    <property name='CanGoPrevious' type='b' access='read'/>"
    "  </interface>"
    "</node>";

const GDBusInterfaceVTable kRootInterfaceVTable = {
    MprisPlayer::HandleMethodCall,
    MprisPlayer::HandleGetProperty,
    MprisPlayer::HandleSetProperty,
    {0}};

const GDBusInterfaceVTable kPlayerInterfaceVTable = {
    MprisPlayer::HandleMethodCall,
    MprisPlayer::HandleGetProperty,
    MprisPlayer::HandleSetProperty,
    {0}};

}  // namespace

MprisPlayer::MprisPlayer(ActionCallback callback)
    : action_callback_(std::move(callback)) {
  GError* error = nullptr;
  introspection_data_ = g_dbus_node_info_new_for_xml(kMprisIntrospectionXml, &error);
  if (error) {
    g_printerr("Failed to parse MPRIS introspection XML: %s\n", error->message);
    g_error_free(error);
  }

  // Set default empty metadata dictionary
  GVariantBuilder builder;
  g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));
  metadata_ = g_variant_builder_end(&builder);
  g_variant_ref_sink(metadata_);
}

MprisPlayer::~MprisPlayer() {
  Deactivate();
  if (metadata_) {
    g_variant_unref(metadata_);
    metadata_ = nullptr;
  }
  if (introspection_data_) {
    g_dbus_node_info_unref(introspection_data_);
    introspection_data_ = nullptr;
  }
}

bool MprisPlayer::Activate() {
  if (is_active_) return true;

  // Use process name or PID to ensure uniqueness in D-Bus well-known name
  const gchar* prgname = g_get_prgname();
  std::string app_name = (prgname && *prgname) ? prgname : "flutter_media_session";
  if (identity_.empty() || identity_ == "Flutter Media Session") {
    identity_ = app_name;
  }
  if (desktop_entry_.empty()) {
    desktop_entry_ = app_name;
  }

  std::string bus_name = "org.mpris.MediaPlayer2." + app_name + ".instance" + std::to_string(getpid());

  owner_id_ = g_bus_own_name(
      G_BUS_TYPE_SESSION,
      bus_name.c_str(),
      G_BUS_NAME_OWNER_FLAGS_NONE,
      OnBusAcquired,
      OnNameAcquired,
      OnNameLost,
      this,
      nullptr);

  is_active_ = true;
  return true;
}

void MprisPlayer::SetDesktopEntry(const std::string& desktop_entry) {
  if (desktop_entry_ == desktop_entry) return;
  desktop_entry_ = desktop_entry;

  if (connection_ && registration_id_root_ > 0) {
    GVariantBuilder builder;
    g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));
    g_variant_builder_add(&builder, "{sv}", "DesktopEntry",
                          g_variant_new_string(desktop_entry_.c_str()));
    EmitPropertiesChanged("org.mpris.MediaPlayer2", &builder);
  }
}

void MprisPlayer::SetIdentity(const std::string& identity) {
  if (identity_ == identity) return;
  identity_ = identity;

  if (connection_ && registration_id_root_ > 0) {
    GVariantBuilder builder;
    g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));
    g_variant_builder_add(&builder, "{sv}", "Identity",
                          g_variant_new_string(identity_.c_str()));
    EmitPropertiesChanged("org.mpris.MediaPlayer2", &builder);
  }
}

void MprisPlayer::Deactivate() {
  if (!is_active_) return;

  if (connection_) {
    if (registration_id_root_ > 0) {
      g_dbus_connection_unregister_object(connection_, registration_id_root_);
      registration_id_root_ = 0;
    }
    if (registration_id_player_ > 0) {
      g_dbus_connection_unregister_object(connection_, registration_id_player_);
      registration_id_player_ = 0;
    }
    g_object_unref(connection_);
    connection_ = nullptr;
  }

  if (owner_id_ > 0) {
    g_bus_unown_name(owner_id_);
    owner_id_ = 0;
  }

  is_active_ = false;
}

void MprisPlayer::OnBusAcquired(GDBusConnection* connection,
                               const gchar* name,
                               gpointer user_data) {
  auto* self = static_cast<MprisPlayer*>(user_data);
  self->connection_ = G_DBUS_CONNECTION(g_object_ref(connection));

  if (!self->introspection_data_) return;

  GError* error = nullptr;

  // Register org.mpris.MediaPlayer2
  GDBusInterfaceInfo* root_interface =
      g_dbus_node_info_lookup_interface(self->introspection_data_, "org.mpris.MediaPlayer2");
  if (root_interface) {
    self->registration_id_root_ = g_dbus_connection_register_object(
        connection,
        "/org/mpris/MediaPlayer2",
        root_interface,
        &kRootInterfaceVTable,
        self,
        nullptr,
        &error);
    if (error) {
      g_printerr("Error registering MPRIS root interface: %s\n", error->message);
      g_clear_error(&error);
    }
  }

  // Register org.mpris.MediaPlayer2.Player
  GDBusInterfaceInfo* player_interface =
      g_dbus_node_info_lookup_interface(self->introspection_data_, "org.mpris.MediaPlayer2.Player");
  if (player_interface) {
    self->registration_id_player_ = g_dbus_connection_register_object(
        connection,
        "/org/mpris/MediaPlayer2",
        player_interface,
        &kPlayerInterfaceVTable,
        self,
        nullptr,
        &error);
    if (error) {
      g_printerr("Error registering MPRIS Player interface: %s\n", error->message);
      g_clear_error(&error);
    }
  }
}

void MprisPlayer::OnNameAcquired(GDBusConnection* connection,
                                 const gchar* name,
                                 gpointer user_data) {}

void MprisPlayer::OnNameLost(GDBusConnection* connection,
                             const gchar* name,
                             gpointer user_data) {}

void MprisPlayer::EmitPropertiesChanged(const gchar* interface_name,
                                        GVariantBuilder* changed_properties) {
  if (!connection_) return;

  GVariantBuilder invalidated_builder;
  g_variant_builder_init(&invalidated_builder, G_VARIANT_TYPE("as"));

  GVariant* parameters = g_variant_new(
      "(sa{sv}as)",
      interface_name,
      changed_properties,
      &invalidated_builder);

  GError* error = nullptr;
  g_dbus_connection_emit_signal(
      connection_,
      nullptr,
      "/org/mpris/MediaPlayer2",
      "org.freedesktop.DBus.Properties",
      "PropertiesChanged",
      parameters,
      &error);

  if (error) {
    g_printerr("Failed to emit PropertiesChanged signal: %s\n", error->message);
    g_error_free(error);
  }
}

void MprisPlayer::UpdateMetadata(GVariant* metadata_dict) {
  if (metadata_) {
    g_variant_unref(metadata_);
  }
  metadata_ = metadata_dict ? g_variant_ref_sink(metadata_dict) : nullptr;

  if (connection_) {
    GVariantBuilder builder;
    g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));
    if (metadata_) {
      g_variant_builder_add(&builder, "{sv}", "Metadata", metadata_);
    }
    EmitPropertiesChanged("org.mpris.MediaPlayer2.Player", &builder);
  }
}

void MprisPlayer::UpdatePlaybackState(const std::string& status,
                                     int64_t position_ms,
                                     double speed,
                                     const std::string& repeat_mode,
                                     bool shuffle_enabled) {
  playback_status_ = status;
  position_us_ = position_ms * 1000;
  rate_ = speed;
  loop_status_ = repeat_mode;
  shuffle_ = shuffle_enabled;

  if (connection_) {
    GVariantBuilder builder;
    g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));

    g_variant_builder_add(&builder, "{sv}", "PlaybackStatus", g_variant_new_string(playback_status_.c_str()));
    g_variant_builder_add(&builder, "{sv}", "Position", g_variant_new_int64(position_us_));
    g_variant_builder_add(&builder, "{sv}", "Rate", g_variant_new_double(rate_));
    g_variant_builder_add(&builder, "{sv}", "LoopStatus", g_variant_new_string(loop_status_.c_str()));
    g_variant_builder_add(&builder, "{sv}", "Shuffle", g_variant_new_boolean(shuffle_));

    EmitPropertiesChanged("org.mpris.MediaPlayer2.Player", &builder);
  }
}

void MprisPlayer::UpdateAvailableActions(const std::unordered_set<std::string>& actions) {
  can_play_ = actions.find("play") != actions.end();
  can_pause_ = actions.find("pause") != actions.end();
  can_seek_ = actions.find("seekTo") != actions.end() ||
              actions.find("rewind") != actions.end() ||
              actions.find("fastForward") != actions.end();
  can_go_next_ = actions.find("skipToNext") != actions.end();
  can_go_previous_ = actions.find("skipToPrevious") != actions.end();

  if (connection_) {
    GVariantBuilder builder;
    g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));

    g_variant_builder_add(&builder, "{sv}", "CanPlay", g_variant_new_boolean(can_play_));
    g_variant_builder_add(&builder, "{sv}", "CanPause", g_variant_new_boolean(can_pause_));
    g_variant_builder_add(&builder, "{sv}", "CanSeek", g_variant_new_boolean(can_seek_));
    g_variant_builder_add(&builder, "{sv}", "CanGoNext", g_variant_new_boolean(can_go_next_));
    g_variant_builder_add(&builder, "{sv}", "CanGoPrevious", g_variant_new_boolean(can_go_previous_));

    EmitPropertiesChanged("org.mpris.MediaPlayer2.Player", &builder);
  }
}

void MprisPlayer::HandleMethodCall(GDBusConnection* connection,
                                  const gchar* sender,
                                  const gchar* object_path,
                                  const gchar* interface_name,
                                  const gchar* method_name,
                                  GVariant* parameters,
                                  GDBusMethodInvocation* invocation,
                                  gpointer user_data) {
  auto* self = static_cast<MprisPlayer*>(user_data);

  if (g_strcmp0(interface_name, "org.mpris.MediaPlayer2") == 0) {
    if (g_strcmp0(method_name, "Raise") == 0 || g_strcmp0(method_name, "Quit") == 0) {
      g_dbus_method_invocation_return_value(invocation, nullptr);
      return;
    }
  } else if (g_strcmp0(interface_name, "org.mpris.MediaPlayer2.Player") == 0) {
    if (g_strcmp0(method_name, "Play") == 0) {
      if (self->action_callback_) self->action_callback_("play", -1);
      g_dbus_method_invocation_return_value(invocation, nullptr);
      return;
    } else if (g_strcmp0(method_name, "Pause") == 0) {
      if (self->action_callback_) self->action_callback_("pause", -1);
      g_dbus_method_invocation_return_value(invocation, nullptr);
      return;
    } else if (g_strcmp0(method_name, "PlayPause") == 0) {
      // Toggle play / pause based on current playback status
      if (self->playback_status_ == "Playing") {
        if (self->action_callback_) self->action_callback_("pause", -1);
      } else {
        if (self->action_callback_) self->action_callback_("play", -1);
      }
      g_dbus_method_invocation_return_value(invocation, nullptr);
      return;
    } else if (g_strcmp0(method_name, "Stop") == 0) {
      if (self->action_callback_) self->action_callback_("stop", -1);
      g_dbus_method_invocation_return_value(invocation, nullptr);
      return;
    } else if (g_strcmp0(method_name, "Next") == 0) {
      if (self->action_callback_) self->action_callback_("skipToNext", -1);
      g_dbus_method_invocation_return_value(invocation, nullptr);
      return;
    } else if (g_strcmp0(method_name, "Previous") == 0) {
      if (self->action_callback_) self->action_callback_("skipToPrevious", -1);
      g_dbus_method_invocation_return_value(invocation, nullptr);
      return;
    } else if (g_strcmp0(method_name, "Seek") == 0) {
      int64_t offset_us = 0;
      g_variant_get(parameters, "(x)", &offset_us);
      int64_t target_ms = (self->position_us_ + offset_us) / 1000;
      if (target_ms < 0) target_ms = 0;
      if (self->action_callback_) self->action_callback_("seekTo", target_ms);
      g_dbus_method_invocation_return_value(invocation, nullptr);
      return;
    } else if (g_strcmp0(method_name, "SetPosition") == 0) {
      const gchar* track_id = nullptr;
      int64_t position_us = 0;
      g_variant_get(parameters, "(&ox)", &track_id, &position_us);
      int64_t target_ms = position_us / 1000;
      if (target_ms < 0) target_ms = 0;
      if (self->action_callback_) self->action_callback_("seekTo", target_ms);
      g_dbus_method_invocation_return_value(invocation, nullptr);
      return;
    }
  }

  g_dbus_method_invocation_return_value(invocation, nullptr);
}

GVariant* MprisPlayer::HandleGetProperty(GDBusConnection* connection,
                                        const gchar* sender,
                                        const gchar* object_path,
                                        const gchar* interface_name,
                                        const gchar* property_name,
                                        GError** error,
                                        gpointer user_data) {
  auto* self = static_cast<MprisPlayer*>(user_data);

  if (g_strcmp0(interface_name, "org.mpris.MediaPlayer2") == 0) {
    if (g_strcmp0(property_name, "CanQuit") == 0) return g_variant_new_boolean(FALSE);
    if (g_strcmp0(property_name, "CanRaise") == 0) return g_variant_new_boolean(FALSE);
    if (g_strcmp0(property_name, "HasTrackList") == 0) return g_variant_new_boolean(FALSE);
    if (g_strcmp0(property_name, "Identity") == 0) return g_variant_new_string(self->identity_.c_str());
    if (g_strcmp0(property_name, "DesktopEntry") == 0) return g_variant_new_string(self->desktop_entry_.c_str());
    if (g_strcmp0(property_name, "SupportedUriSchemes") == 0) return g_variant_new_strv(nullptr, 0);
    if (g_strcmp0(property_name, "SupportedMimeTypes") == 0) return g_variant_new_strv(nullptr, 0);
  } else if (g_strcmp0(interface_name, "org.mpris.MediaPlayer2.Player") == 0) {
    if (g_strcmp0(property_name, "PlaybackStatus") == 0) return g_variant_new_string(self->playback_status_.c_str());
    if (g_strcmp0(property_name, "LoopStatus") == 0) return g_variant_new_string(self->loop_status_.c_str());
    if (g_strcmp0(property_name, "Rate") == 0) return g_variant_new_double(self->rate_);
    if (g_strcmp0(property_name, "Shuffle") == 0) return g_variant_new_boolean(self->shuffle_);
    if (g_strcmp0(property_name, "Position") == 0) return g_variant_new_int64(self->position_us_);
    if (g_strcmp0(property_name, "Metadata") == 0) {
      return self->metadata_ ? g_variant_ref(self->metadata_) : g_variant_new_array(G_VARIANT_TYPE("{sv}"), nullptr, 0);
    }
    if (g_strcmp0(property_name, "Volume") == 0) return g_variant_new_double(1.0);
    if (g_strcmp0(property_name, "MinimumRate") == 0) return g_variant_new_double(1.0);
    if (g_strcmp0(property_name, "MaximumRate") == 0) return g_variant_new_double(1.0);
    if (g_strcmp0(property_name, "CanControl") == 0) return g_variant_new_boolean(self->can_control_);
    if (g_strcmp0(property_name, "CanPlay") == 0) return g_variant_new_boolean(self->can_play_);
    if (g_strcmp0(property_name, "CanPause") == 0) return g_variant_new_boolean(self->can_pause_);
    if (g_strcmp0(property_name, "CanSeek") == 0) return g_variant_new_boolean(self->can_seek_);
    if (g_strcmp0(property_name, "CanGoNext") == 0) return g_variant_new_boolean(self->can_go_next_);
    if (g_strcmp0(property_name, "CanGoPrevious") == 0) return g_variant_new_boolean(self->can_go_previous_);
  }

  return nullptr;
}

gboolean MprisPlayer::HandleSetProperty(GDBusConnection* connection,
                                       const gchar* sender,
                                       const gchar* object_path,
                                       const gchar* interface_name,
                                       const gchar* property_name,
                                       GVariant* value,
                                       GError** error,
                                       gpointer user_data) {
  auto* self = static_cast<MprisPlayer*>(user_data);

  if (g_strcmp0(interface_name, "org.mpris.MediaPlayer2.Player") == 0) {
    if (g_strcmp0(property_name, "LoopStatus") == 0) {
      if (self->action_callback_) self->action_callback_("repeat", -1);
      return TRUE;
    } else if (g_strcmp0(property_name, "Shuffle") == 0) {
      if (self->action_callback_) self->action_callback_("shuffle", -1);
      return TRUE;
    }
  }

  return FALSE;
}

}  // namespace flutter_media_session
