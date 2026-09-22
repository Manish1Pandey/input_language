/// Web implementation of `input_language`.
///
/// Browsers do not expose the keyboard / IME language. This implementation
/// reports `navigator.language` as a *weak* hint
/// ([InputLanguageSource.browserLocale]) and watches the `languagechange`
/// event; `AutoDirectionTextField` lets typed text override it.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/capabilities.dart';
import 'src/input_language.dart';
import 'src/platform_interface.dart';

/// [KeyboardLanguagePlatform] for the web.
class KeyboardLanguageWeb extends KeyboardLanguagePlatform {
  /// Creates the web implementation.
  KeyboardLanguageWeb();

  /// Registers this class as the platform implementation.
  static void registerWith(Registrar registrar) {
    KeyboardLanguagePlatform.instance = KeyboardLanguageWeb();
  }

  InputLanguage? _fromTag(String tag) {
    if (!isLanguageBearingTag(tag)) return null;
    return InputLanguage(
      languageTag: tag,
      source: InputLanguageSource.browserLocale,
      displayName: _displayName(tag),
      inputSourceId: tag,
    );
  }

  String? _displayName(String tag) {
    try {
      final names = _IntlDisplayNames(
        <JSString>[tag.toJS].toJS,
        _DisplayNamesOptions(type: 'language'),
      );
      return names.of(tag)?.toDart;
    } on Object {
      return null;
    }
  }

  @override
  Future<InputLanguage?> getCurrent() async =>
      _fromTag(web.window.navigator.language);

  @override
  Stream<InputLanguage?> watch({required Duration pollInterval}) {
    late final StreamController<InputLanguage?> controller;
    JSFunction? listener;
    controller = StreamController<InputLanguage?>(
      onListen: () {
        controller.add(_fromTag(web.window.navigator.language));
        listener = ((web.Event _) {
          controller.add(_fromTag(web.window.navigator.language));
        }).toJS;
        web.window.addEventListener('languagechange', listener);
      },
      onCancel: () {
        final registered = listener;
        if (registered != null) {
          web.window.removeEventListener('languagechange', registered);
        }
        listener = null;
      },
    );
    return controller.stream;
  }

  @override
  Future<List<InputLanguage>> getAvailable() async {
    final result = <InputLanguage>[];
    for (final tag in web.window.navigator.languages.toDart) {
      final language = _fromTag(tag.toDart);
      if (language != null && !result.contains(language)) result.add(language);
    }
    return List<InputLanguage>.unmodifiable(result);
  }

  @override
  Future<bool> setLanguage(String languageTag) {
    throw UnsupportedError(
      'Browsers do not let web pages change the keyboard or input method.',
    );
  }

  @override
  Future<KeyboardLanguageCapabilities> getCapabilities() async =>
      const KeyboardLanguageCapabilities(
        canReadCurrent: true,
        canObserveChanges: true,
        canListAvailable: true,
        canSetLanguage: false,
        requiresFocusedTextField: false,
        isWeakHint: true,
      );
}

@JS('Intl.DisplayNames')
extension type _IntlDisplayNames._(JSObject _) implements JSObject {
  external factory _IntlDisplayNames(
    JSArray<JSString> locales,
    _DisplayNamesOptions options,
  );

  external JSString? of(String code);
}

extension type _DisplayNamesOptions._(JSObject _) implements JSObject {
  external factory _DisplayNamesOptions({String type});
}
