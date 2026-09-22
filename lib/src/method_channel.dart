import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'capabilities.dart';
import 'input_language.dart';
import 'platform_interface.dart';

/// [KeyboardLanguagePlatform] backed by the native iOS, Android, macOS and
/// Windows implementations over platform channels.
class MethodChannelKeyboardLanguage extends KeyboardLanguagePlatform {
  /// The method channel shared with the native code.
  @visibleForTesting
  static const MethodChannel methodChannel = MethodChannel(
    'dev.manishpanday/keyboard_language',
  );

  /// The event channel that streams keyboard-language changes.
  @visibleForTesting
  static const EventChannel eventChannel = EventChannel(
    'dev.manishpanday/keyboard_language/events',
  );

  @override
  Future<InputLanguage?> getCurrent() async {
    try {
      final map = await methodChannel.invokeMapMethod<Object?, Object?>(
        'getCurrent',
      );
      return InputLanguage.fromMap(map);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Stream<InputLanguage?> watch({required Duration pollInterval}) {
    return eventChannel
        .receiveBroadcastStream(<String, Object>{
          'pollIntervalMs': pollInterval.inMilliseconds,
        })
        .map((event) => event is Map ? InputLanguage.fromMap(event) : null);
  }

  @override
  Future<List<InputLanguage>> getAvailable() async {
    try {
      final list = await methodChannel.invokeListMethod<Object?>(
        'getAvailable',
      );
      if (list == null) return const <InputLanguage>[];
      final result = <InputLanguage>[];
      for (final item in list) {
        if (item is Map) {
          final language = InputLanguage.fromMap(item);
          if (language != null && !result.contains(language)) {
            result.add(language);
          }
        }
      }
      return List<InputLanguage>.unmodifiable(result);
    } on MissingPluginException {
      return const <InputLanguage>[];
    }
  }

  @override
  Future<bool> setLanguage(String languageTag) async {
    try {
      final ok = await methodChannel.invokeMethod<bool>(
        'setLanguage',
        <String, Object>{'languageTag': languageTag},
      );
      return ok ?? false;
    } on MissingPluginException {
      throw UnsupportedError(
        'Switching the keyboard language is not supported on this platform.',
      );
    } on PlatformException catch (e) {
      if (e.code == 'unsupported') {
        throw UnsupportedError(
          e.message ??
              'Switching the keyboard language is not supported on this '
                  'platform.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<KeyboardLanguageCapabilities> getCapabilities() async {
    try {
      final map = await methodChannel.invokeMapMethod<Object?, Object?>(
        'getCapabilities',
      );
      return map == null
          ? KeyboardLanguageCapabilities.none
          : KeyboardLanguageCapabilities.fromMap(map);
    } on MissingPluginException {
      return KeyboardLanguageCapabilities.none;
    }
  }
}
