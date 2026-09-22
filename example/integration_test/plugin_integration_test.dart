// Runs against the real native implementation:
//   flutter test integration_test -d macos
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:input_language/input_language.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reads capabilities from the native side', (tester) async {
    final caps = await KeyboardLanguage.capabilities();
    debugPrint('capabilities: $caps');
    expect(caps.canReadCurrent, isTrue);
  });

  testWidgets(
    'desktop: reads, lists and re-selects the current keyboard',
    (tester) async {
      final current = await KeyboardLanguage.current;
      debugPrint('current: $current');
      expect(current, isNotNull);
      expect(current!.languageTag, isNotEmpty);
      expect(current.source, InputLanguageSource.keyboardLayout);

      final available = await KeyboardLanguage.available();
      debugPrint('available: $available');
      expect(available, isNotEmpty);

      // Selecting the language that is already active is a safe round trip.
      expect(await KeyboardLanguage.setLanguage(current.languageTag), isTrue);
      expect(
        (await KeyboardLanguage.current)!.languageTag,
        current.languageTag,
      );

      final first = await KeyboardLanguage.onChanged.first;
      expect(first?.languageTag, current.languageTag);
    },
    skip: kIsWeb || !(Platform.isMacOS || Platform.isWindows),
  );
}
