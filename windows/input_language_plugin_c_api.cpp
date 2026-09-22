#include "include/input_language/input_language_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "input_language_plugin.h"

void InputLanguagePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  input_language::InputLanguagePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
