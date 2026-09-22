import 'package:flutter/foundation.dart';

/// What the current platform lets this package do.
@immutable
class KeyboardLanguageCapabilities {
  /// Creates a capabilities description.
  const KeyboardLanguageCapabilities({
    required this.canReadCurrent,
    required this.canObserveChanges,
    required this.canListAvailable,
    required this.canSetLanguage,
    required this.requiresFocusedTextField,
    required this.isWeakHint,
  });

  /// Capabilities of a platform with no implementation at all.
  static const KeyboardLanguageCapabilities none = KeyboardLanguageCapabilities(
    canReadCurrent: false,
    canObserveChanges: false,
    canListAvailable: false,
    canSetLanguage: false,
    requiresFocusedTextField: false,
    isWeakHint: false,
  );

  /// Decodes the platform-channel map.
  factory KeyboardLanguageCapabilities.fromMap(Map<Object?, Object?> map) {
    bool flag(String key) => map[key] == true;
    return KeyboardLanguageCapabilities(
      canReadCurrent: flag('canReadCurrent'),
      canObserveChanges: flag('canObserveChanges'),
      canListAvailable: flag('canListAvailable'),
      canSetLanguage: flag('canSetLanguage'),
      requiresFocusedTextField: flag('requiresFocusedTextField'),
      isWeakHint: flag('isWeakHint'),
    );
  }

  /// `KeyboardLanguage.current` can return a real value.
  final bool canReadCurrent;

  /// `KeyboardLanguage.onChanged` emits when the user switches keyboards.
  final bool canObserveChanges;

  /// `KeyboardLanguage.available()` returns the enabled keyboards.
  final bool canListAvailable;

  /// `KeyboardLanguage.setLanguage` is implemented (macOS and Windows only).
  final bool canSetLanguage;

  /// The value is only meaningful while a text field has focus (iOS).
  final bool requiresFocusedTextField;

  /// The reported value is only a hint (web: the browser UI language).
  final bool isWeakHint;

  /// Encodes this value as the platform-channel map.
  Map<String, bool> toMap() => <String, bool>{
    'canReadCurrent': canReadCurrent,
    'canObserveChanges': canObserveChanges,
    'canListAvailable': canListAvailable,
    'canSetLanguage': canSetLanguage,
    'requiresFocusedTextField': requiresFocusedTextField,
    'isWeakHint': isWeakHint,
  };

  @override
  bool operator ==(Object other) =>
      other is KeyboardLanguageCapabilities &&
      mapEquals(other.toMap(), toMap());

  @override
  int get hashCode => Object.hashAll(toMap().values);

  @override
  String toString() => 'KeyboardLanguageCapabilities(${toMap()})';
}
