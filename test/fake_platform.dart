import 'dart:async';

import 'package:input_language/input_language.dart';

/// In-memory [KeyboardLanguagePlatform] driven by the tests.
class FakeKeyboardLanguagePlatform extends KeyboardLanguagePlatform {
  InputLanguage? current;
  List<InputLanguage> available = const <InputLanguage>[];
  bool supportsSet = false;
  final List<String> setRequests = <String>[];
  final List<Duration> watchIntervals = <Duration>[];
  int activeWatchers = 0;
  StreamController<InputLanguage?>? _controller;

  /// Pushes a keyboard change to the active watcher.
  void emit(InputLanguage? language) {
    current = language;
    _controller?.add(language);
  }

  @override
  Future<InputLanguage?> getCurrent() async => current;

  @override
  Stream<InputLanguage?> watch({required Duration pollInterval}) {
    watchIntervals.add(pollInterval);
    late final StreamController<InputLanguage?> controller;
    controller = StreamController<InputLanguage?>(
      onListen: () {
        activeWatchers++;
        _controller = controller;
        controller.add(current);
      },
      onCancel: () {
        activeWatchers--;
        if (identical(_controller, controller)) _controller = null;
      },
    );
    return controller.stream;
  }

  @override
  Future<List<InputLanguage>> getAvailable() async => available;

  @override
  Future<bool> setLanguage(String languageTag) async {
    if (!supportsSet) {
      throw UnsupportedError('not supported by the fake');
    }
    setRequests.add(languageTag);
    final match = available.where(
      (l) => l.languageTag.toLowerCase() == languageTag.toLowerCase(),
    );
    if (match.isEmpty) return false;
    emit(match.first);
    return true;
  }

  @override
  Future<KeyboardLanguageCapabilities> getCapabilities() async =>
      KeyboardLanguageCapabilities(
        canReadCurrent: true,
        canObserveChanges: true,
        canListAvailable: true,
        canSetLanguage: supportsSet,
        requiresFocusedTextField: false,
        isWeakHint: false,
      );
}

InputLanguage lang(
  String tag, {
  InputLanguageSource source = InputLanguageSource.inputMethod,
}) => InputLanguage(languageTag: tag, source: source);
