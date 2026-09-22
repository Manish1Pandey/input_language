import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyboard_language/keyboard_language.dart';
import 'package:keyboard_language_example/main.dart';

class _Platform extends KeyboardLanguagePlatform {
  final StreamController<InputLanguage?> events =
      StreamController<InputLanguage?>.broadcast();

  @override
  Future<InputLanguage?> getCurrent() async => InputLanguage(
    languageTag: 'en-US',
    source: InputLanguageSource.inputMethod,
  );

  @override
  Stream<InputLanguage?> watch({required Duration pollInterval}) =>
      events.stream;

  @override
  Future<List<InputLanguage>> getAvailable() async => <InputLanguage>[
    InputLanguage(
      languageTag: 'en-US',
      source: InputLanguageSource.inputMethod,
    ),
    InputLanguage(languageTag: 'ar', source: InputLanguageSource.inputMethod),
  ];

  @override
  Future<bool> setLanguage(String languageTag) =>
      throw UnsupportedError('Apps cannot switch keyboards here.');

  @override
  Future<KeyboardLanguageCapabilities> getCapabilities() async =>
      const KeyboardLanguageCapabilities(
        canReadCurrent: true,
        canObserveChanges: true,
        canListAvailable: true,
        canSetLanguage: false,
        requiresFocusedTextField: false,
        isWeakHint: false,
      );
}

void main() {
  testWidgets('demo shows current language, list and reacts to changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final platform = _Platform();
    KeyboardLanguagePlatform.instance = platform;
    await tester.pumpWidget(const KeyboardLanguageDemoApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('en-US · LTR · inputMethod'), findsWidgets);
    expect(find.text('ar'), findsOneWidget);

    platform.events.add(
      InputLanguage(languageTag: 'ar', source: InputLanguageSource.inputMethod),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ar · RTL · inputMethod'), findsWidgets);

    await tester.tap(find.widgetWithText(ActionChip, 'ar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unsupported:'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await platform.events.close();
  });
}
