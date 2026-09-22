import 'dart:async';

import 'package:flutter/foundation.dart';

import 'capabilities.dart';
import 'input_language.dart';
import 'platform_interface.dart';

/// Reads, observes and (on macOS / Windows) switches the active keyboard /
/// input language.
///
/// ```dart
/// final language = await KeyboardLanguage.current;
/// print(language?.languageTag); // e.g. "ar", "he-IL", "en-US"
/// KeyboardLanguage.onChanged.listen((l) => print('now typing in $l'));
/// ```
///
/// On iOS the value is only reliable while a text field is focused, because
/// iOS reports the input mode of the first responder (Flutter's hidden text
/// input view while editing). See `capabilities()`.
abstract final class KeyboardLanguage {
  /// Interval used by platforms that have no change notification (Android
  /// subtype changes, Linux IBus) while [onChanged] has listeners. Takes
  /// effect the next time listening starts. Defaults to 500 ms; values below
  /// 100 ms are clamped to 100 ms.
  static Duration pollInterval = const Duration(milliseconds: 500);

  static StreamController<InputLanguage?>? _controller;
  static StreamSubscription<InputLanguage?>? _subscription;
  static bool _hasLast = false;
  static InputLanguage? _last;

  /// The keyboard language the user is typing with right now, or `null` when
  /// the platform cannot tell (iOS with no focused text field, emoji keyboard,
  /// unsupported Linux desktop, platforms with no implementation).
  static Future<InputLanguage?> get current =>
      KeyboardLanguagePlatform.instance.getCurrent();

  /// Broadcast stream of keyboard-language changes.
  ///
  /// The native observer runs only while this stream has listeners. When
  /// listening starts the platform emits the current value (where it can),
  /// then one event per actual change; consecutive duplicates are dropped.
  /// `null` means "no language-bearing keyboard is known right now".
  static Stream<InputLanguage?> get onChanged {
    return (_controller ??= StreamController<InputLanguage?>.broadcast(
      onListen: _startWatching,
      onCancel: _stopWatching,
    )).stream;
  }

  static void _startWatching() {
    final interval = pollInterval < const Duration(milliseconds: 100)
        ? const Duration(milliseconds: 100)
        : pollInterval;
    _subscription = KeyboardLanguagePlatform.instance
        .watch(pollInterval: interval)
        .listen(
          (language) {
            if (_hasLast && language == _last) return;
            _hasLast = true;
            _last = language;
            _controller?.add(language);
          },
          onError: (Object error, StackTrace stackTrace) =>
              _controller?.addError(error, stackTrace),
        );
  }

  static Future<void> _stopWatching() async {
    final subscription = _subscription;
    _subscription = null;
    _hasLast = false;
    _last = null;
    await subscription?.cancel();
  }

  /// The keyboards / input languages the user has enabled: iOS
  /// `activeInputModes`, Android subtypes of the current input method, macOS
  /// select-capable keyboard input sources, Windows installed layouts, Linux
  /// GNOME input sources, web `navigator.languages`. Empty when unknown.
  static Future<List<InputLanguage>> available() =>
      KeyboardLanguagePlatform.instance.getAvailable();

  /// Switches the active keyboard to an installed one whose language matches
  /// [languageTag] (exact tag first, then same language with any region).
  ///
  /// Implemented on **macOS** (`TISSelectInputSource`) and **Windows**
  /// (`ActivateKeyboardLayout`). Returns `false` when no installed keyboard
  /// matches. Throws [UnsupportedError] on iOS, Android, Linux and web, where
  /// apps cannot change the user's keyboard (flutter/flutter#99606).
  static Future<bool> setLanguage(String languageTag) {
    if (!isLanguageBearingTag(languageTag)) {
      throw ArgumentError.value(
        languageTag,
        'languageTag',
        'must be a BCP-47 language tag',
      );
    }
    return KeyboardLanguagePlatform.instance.setLanguage(
      canonicalizeLanguageTag(languageTag),
    );
  }

  /// What the current platform supports.
  static Future<KeyboardLanguageCapabilities> capabilities() =>
      KeyboardLanguagePlatform.instance.getCapabilities();

  /// Stops any active watcher and forgets cached state. For tests that swap
  /// [KeyboardLanguagePlatform.instance].
  @visibleForTesting
  static Future<void> resetForTesting() async {
    await _stopWatching();
    final controller = _controller;
    _controller = null;
    await controller?.close();
    pollInterval = const Duration(milliseconds: 500);
  }
}
