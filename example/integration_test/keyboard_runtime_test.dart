// On-device runtime check of the real example app. Run with e.g.
//   flutter test integration_test/keyboard_runtime_test.dart -d <device> \
//     --dart-define=KL_EXPECT_RTL_SWITCH=true
// While the test prints "KL READY_FOR_SWITCH", switch the device keyboard to
// Arabic or Hebrew (for automation: adb shell settings put secure
// selected_input_method_subtype <hash>). With KL_EXPECT_RTL_INITIAL=true the
// keyboard is expected to already be right-to-left when the field is focused.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:input_language/input_language.dart';
import 'package:input_language_example/main.dart';

const bool expectRtlSwitch = bool.fromEnvironment('KL_EXPECT_RTL_SWITCH');
const bool expectRtlInitial = bool.fromEnvironment('KL_EXPECT_RTL_INITIAL');
const bool refocusWhileWaiting = bool.fromEnvironment('KL_REFOCUS');
const int holdSeconds = int.fromEnvironment('KL_HOLD_SECONDS', defaultValue: 8);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('focused field reads the keyboard and follows RTL switches', (
    tester,
  ) async {
    final events = <InputLanguage?>[];
    final sub = KeyboardLanguage.onChanged.listen(events.add);

    await tester.pumpWidget(const KeyboardLanguageDemoApp());
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('auto-field'));
    final textField = find.descendant(
      of: field,
      matching: find.byType(TextField),
    );
    await tester.tap(field);
    await tester.pump();
    // Give the OS time to show the keyboard and bind the input view.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final current = await KeyboardLanguage.current;
    final caps = await KeyboardLanguage.capabilities();
    final available = await KeyboardLanguage.available();
    debugPrint('KL capabilities: $caps');
    debugPrint('KL current (focused): $current');
    debugPrint('KL available: $available');
    debugPrint('KL events so far: $events');
    expect(current, isNotNull, reason: 'keyboard language while focused');
    expect(
      tester.widget<TextField>(textField).textDirection,
      current!.isRtl ? TextDirection.rtl : TextDirection.ltr,
    );

    if (expectRtlInitial) {
      expect(current.isRtl, isTrue);
      expect(events.whereType<InputLanguage>().any((l) => l.isRtl), isTrue);
    }

    if (expectRtlSwitch) {
      expect(current.isRtl, isFalse, reason: 'start from an LTR keyboard');
      debugPrint('KL READY_FOR_SWITCH');
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      var ticks = 0;
      while (!events.any((l) => l?.isRtl ?? false) &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 250));
        // Optionally blur and refocus the field every 3 s, as a user tapping
        // away and back would, so the OS re-reads keyboard preferences.
        if (refocusWhileWaiting && ++ticks % 12 == 0) {
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.tap(field);
          await tester.pump();
        }
      }
      debugPrint('KL events after switch: $events');
      expect(events.any((l) => l?.isRtl ?? false), isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<TextField>(textField).textDirection,
        TextDirection.rtl,
      );
      debugPrint('KL field direction flipped to RTL');
    }

    await tester.enterText(textField, 'abc');
    await tester.pump(const Duration(milliseconds: 300));
    debugPrint(
      'KL direction with "abc" typed: '
      '${tester.widget<TextField>(textField).textDirection}',
    );
    debugPrint('KL HOLD_FOR_SCREENSHOT');
    for (var i = 0; i < holdSeconds * 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await sub.cancel();
  });
}
