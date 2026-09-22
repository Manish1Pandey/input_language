import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:input_language/input_language.dart';

import 'fake_platform.dart';

void main() {
  late FakeKeyboardLanguagePlatform fake;

  setUp(() {
    fake = FakeKeyboardLanguagePlatform();
    KeyboardLanguagePlatform.instance = fake;
  });

  tearDown(KeyboardLanguage.resetForTesting);

  TextDirection? fieldDirection(WidgetTester tester, Finder finder) =>
      tester.widget<TextField>(finder).textDirection;

  Widget app(Widget child) => MaterialApp(
    home: Scaffold(body: Column(children: <Widget>[child])),
  );

  testWidgets('AutoDirectionTextField follows typed text without a keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(app(const AutoDirectionTextField()));
    final field = find.byType(TextField);
    expect(fieldDirection(tester, field), TextDirection.ltr);

    await tester.enterText(field, 'שלום עולם');
    await tester.pump();
    expect(fieldDirection(tester, field), TextDirection.rtl);

    await tester.enterText(field, '42 hello');
    await tester.pump();
    expect(fieldDirection(tester, field), TextDirection.ltr);
  });

  testWidgets('keyboard language decides while the field is focused', (
    tester,
  ) async {
    fake.current = lang('en-US');
    final changes = <TextDirection>[];
    final other = FocusNode();
    addTearDown(other.dispose);
    await tester.pumpWidget(
      app(
        Column(
          children: <Widget>[
            AutoDirectionTextField(
              onDirectionChanged: (direction, keyboard) =>
                  changes.add(direction),
            ),
            Focus(focusNode: other, child: const SizedBox(height: 10)),
          ],
        ),
      ),
    );
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();
    expect(fieldDirection(tester, field), TextDirection.ltr);

    // The user switches to an Arabic keyboard.
    fake.emit(lang('ar'));
    await tester.pump();
    expect(fieldDirection(tester, field), TextDirection.rtl);

    // Typed Latin text does not override the keyboard (default policy).
    await tester.enterText(field, 'abc');
    await tester.pump();
    expect(fieldDirection(tester, field), TextDirection.rtl);

    // Unfocused, the keyboard no longer applies; the text decides.
    other.requestFocus();
    await tester.pump();
    expect(fieldDirection(tester, field), TextDirection.ltr);
    expect(changes, <TextDirection>[TextDirection.rtl, TextDirection.ltr]);

    // Let the delayed re-read after focus fire before teardown.
    await tester.pump(KeyboardDirectionController.refocusReadDelay);
  });

  testWidgets('textThenKeyboard keeps an RTL paragraph RTL', (tester) async {
    fake.current = lang('ar');
    final controller = TextEditingController(text: 'مرحبا');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        AutoDirectionTextField(
          controller: controller,
          policy: AutoDirectionPolicy.textThenKeyboard,
        ),
      ),
    );
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();
    fake.emit(lang('en-US'));
    await tester.pump();
    expect(fieldDirection(tester, field), TextDirection.rtl);
    controller.clear();
    await tester.pump();
    expect(fieldDirection(tester, field), TextDirection.ltr);
    await tester.pump(KeyboardDirectionController.refocusReadDelay);
  });

  testWidgets('AutoDirectionBuilder works with TextFormField and fallback', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            child: AutoDirectionBuilder(
              controller: controller,
              policy: AutoDirectionPolicy.textOnly,
              builder: (context, direction, focusNode) => TextFormField(
                controller: controller,
                focusNode: focusNode,
                textDirection: direction,
              ),
            ),
          ),
        ),
      ),
    );
    final field = find.byType(TextField);
    // Nothing typed: ambient Directionality is the fallback.
    expect(fieldDirection(tester, field), TextDirection.rtl);
    await tester.enterText(field, 'Hello');
    await tester.pump();
    expect(fieldDirection(tester, field), TextDirection.ltr);
    // textOnly never starts a keyboard watcher.
    expect(fake.activeWatchers, 0);
  });

  testWidgets('KeyboardDirectionController without a focus node', (
    tester,
  ) async {
    fake.current = lang('he');
    final text = TextEditingController();
    addTearDown(text.dispose);
    final controller = KeyboardDirectionController(textController: text);
    await tester.pump();
    expect(controller.value, TextDirection.rtl);
    expect(controller.keyboardLanguage, lang('he'));
    controller.policy = AutoDirectionPolicy.textOnly;
    expect(controller.value, TextDirection.ltr);
    text.text = 'שלום';
    expect(controller.value, TextDirection.rtl);
    expect(controller.textDirectionFromText, TextDirection.rtl);
    controller.dispose();
    await tester.pump();
    expect(fake.activeWatchers, 0);
  });
}
