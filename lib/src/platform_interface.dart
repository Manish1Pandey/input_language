import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'capabilities.dart';
import 'input_language.dart';
import 'method_channel.dart';

/// The interface every platform implementation of `input_language`
/// implements. Apps use `KeyboardLanguage`; this class is for implementers and
/// tests.
abstract class KeyboardLanguagePlatform extends PlatformInterface {
  /// Constructs a platform implementation.
  KeyboardLanguagePlatform() : super(token: _token);

  static final Object _token = Object();

  static KeyboardLanguagePlatform _instance = MethodChannelKeyboardLanguage();

  /// The implementation in use; defaults to [MethodChannelKeyboardLanguage].
  static KeyboardLanguagePlatform get instance => _instance;

  /// Replaces the implementation (platform registration and tests).
  static set instance(KeyboardLanguagePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Reads the active keyboard language, or `null` when unknown.
  Future<InputLanguage?> getCurrent();

  /// Streams the keyboard language, starting with the current value where the
  /// platform can determine it. [pollInterval] is used by platforms that have
  /// no change notification.
  Stream<InputLanguage?> watch({required Duration pollInterval});

  /// Lists the keyboards / input languages the user has enabled.
  Future<List<InputLanguage>> getAvailable();

  /// Selects the installed keyboard matching [languageTag]. Returns `false`
  /// when none matches; throws [UnsupportedError] where impossible.
  Future<bool> setLanguage(String languageTag);

  /// Describes what this platform supports.
  Future<KeyboardLanguageCapabilities> getCapabilities();
}
