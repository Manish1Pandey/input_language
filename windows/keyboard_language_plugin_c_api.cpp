#include "include/keyboard_language/keyboard_language_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "keyboard_language_plugin.h"

void KeyboardLanguagePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  keyboard_language::KeyboardLanguagePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
