import 'dart:async';

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

  test('current and available delegate to the platform', () async {
    fake.current = lang('ar');
    fake.available = <InputLanguage>[lang('en-US'), lang('ar')];
    expect(await KeyboardLanguage.current, lang('ar'));
    expect(await KeyboardLanguage.available(), fake.available);
  });

  test('onChanged is shared, deduplicated and stops when unused', () async {
    fake.current = lang('en');
    KeyboardLanguage.pollInterval = const Duration(milliseconds: 20);
    final a = <InputLanguage?>[];
    final b = <InputLanguage?>[];
    final subA = KeyboardLanguage.onChanged.listen(a.add);
    final subB = KeyboardLanguage.onChanged.listen(b.add);
    await pumpEventQueue();
    expect(fake.activeWatchers, 1);
    expect(fake.watchIntervals, <Duration>[
      const Duration(milliseconds: 100), // clamped
    ]);

    fake.emit(lang('en')); // duplicate, dropped
    fake.emit(lang('he'));
    fake.emit(lang('he')); // duplicate, dropped
    fake.emit(null);
    await pumpEventQueue();
    expect(a, <InputLanguage?>[lang('en'), lang('he'), null]);
    expect(b, a);

    await subA.cancel();
    expect(fake.activeWatchers, 1);
    await subB.cancel();
    await pumpEventQueue();
    expect(fake.activeWatchers, 0);

    // Listening again restarts the watcher and re-emits the current value.
    final c = <InputLanguage?>[];
    final subC = KeyboardLanguage.onChanged.listen(c.add);
    await pumpEventQueue();
    expect(c, <InputLanguage?>[null]);
    await subC.cancel();
  });

  test('setLanguage canonicalises, validates and surfaces support', () async {
    expect(
      () => KeyboardLanguage.setLanguage('ar'),
      throwsA(isA<UnsupportedError>()),
    );
    expect(() => KeyboardLanguage.setLanguage(''), throwsArgumentError);
    expect(() => KeyboardLanguage.setLanguage('emoji'), throwsArgumentError);

    fake
      ..supportsSet = true
      ..available = <InputLanguage>[lang('en-US'), lang('he-IL')];
    expect(await KeyboardLanguage.setLanguage('he_il'), isTrue);
    expect(fake.setRequests.last, 'he-IL');
    expect(await KeyboardLanguage.current, lang('he-IL'));
    expect(await KeyboardLanguage.setLanguage('ja'), isFalse);
    expect((await KeyboardLanguage.capabilities()).canSetLanguage, isTrue);
  });

  test('errors from the platform stream are forwarded', () async {
    final errors = <Object>[];
    final broken = _ErrorPlatform();
    KeyboardLanguagePlatform.instance = broken;
    final sub = KeyboardLanguage.onChanged.listen((_) {}, onError: errors.add);
    await pumpEventQueue();
    expect(errors.single, isA<StateError>());
    await sub.cancel();
  });
}

class _ErrorPlatform extends FakeKeyboardLanguagePlatform {
  @override
  Stream<InputLanguage?> watch({required Duration pollInterval}) =>
      Stream<InputLanguage?>.error(StateError('boom'));
}
