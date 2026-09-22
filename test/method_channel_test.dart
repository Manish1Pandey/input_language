import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyboard_language/keyboard_language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final platform = MethodChannelKeyboardLanguage();
  final calls = <MethodCall>[];

  void mockMethods(Future<Object?>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(
      MethodChannelKeyboardLanguage.methodChannel,
      (call) {
        calls.add(call);
        return handler(call);
      },
    );
  }

  setUp(calls.clear);

  tearDown(() {
    messenger.setMockMethodCallHandler(
      MethodChannelKeyboardLanguage.methodChannel,
      null,
    );
    messenger.setMockStreamHandler(
      MethodChannelKeyboardLanguage.eventChannel,
      null,
    );
  });

  test('getCurrent decodes the native payload', () async {
    mockMethods(
      (call) async => <String, Object?>{
        'languageTag': 'ar_SA',
        'displayName': 'Arabic',
        'inputSourceId': 'com.apple.keylayout.Arabic',
        'source': 'keyboardLayout',
      },
    );
    final language = await platform.getCurrent();
    expect(calls.single.method, 'getCurrent');
    expect(language!.languageTag, 'ar-SA');
    expect(language.isRtl, isTrue);
    expect(language.source, InputLanguageSource.keyboardLayout);
  });

  test('getCurrent returns null for null, emoji and missing plugin', () async {
    mockMethods((call) async => null);
    expect(await platform.getCurrent(), isNull);
    mockMethods((call) async => <String, Object?>{'languageTag': 'emoji'});
    expect(await platform.getCurrent(), isNull);
    messenger.setMockMethodCallHandler(
      MethodChannelKeyboardLanguage.methodChannel,
      null,
    );
    expect(await platform.getCurrent(), isNull);
    expect(await platform.getAvailable(), isEmpty);
    expect(await platform.getCapabilities(), KeyboardLanguageCapabilities.none);
    expect(() => platform.setLanguage('ar'), throwsA(isA<UnsupportedError>()));
  });

  test('getAvailable skips unusable entries and duplicates', () async {
    mockMethods(
      (call) async => <Object?>[
        <String, Object?>{'languageTag': 'en-US', 'source': 'inputMethod'},
        <String, Object?>{'languageTag': 'emoji', 'source': 'inputMethod'},
        <String, Object?>{'languageTag': 'he', 'source': 'inputMethod'},
        <String, Object?>{'languageTag': 'en_US', 'source': 'inputMethod'},
        'garbage',
      ],
    );
    final list = await platform.getAvailable();
    expect(list.map((l) => l.languageTag), <String>['en-US', 'he']);
  });

  test('setLanguage passes the tag and maps "unsupported"', () async {
    mockMethods((call) async {
      if ((call.arguments as Map)['languageTag'] == 'fa') return true;
      throw PlatformException(code: 'unsupported', message: 'nope');
    });
    expect(await platform.setLanguage('fa'), isTrue);
    expect(calls.single.arguments, <String, Object>{'languageTag': 'fa'});
    expect(
      () => platform.setLanguage('ar'),
      throwsA(
        isA<UnsupportedError>().having((e) => e.message, 'message', 'nope'),
      ),
    );
  });

  test('setLanguage rethrows other platform errors', () async {
    mockMethods((call) async => throw PlatformException(code: 'bad_args'));
    expect(() => platform.setLanguage('ar'), throwsA(isA<PlatformException>()));
  });

  test('getCapabilities decodes flags', () async {
    mockMethods(
      (call) async => <String, Object?>{
        'canReadCurrent': true,
        'canObserveChanges': true,
        'canListAvailable': false,
        'canSetLanguage': false,
        'requiresFocusedTextField': true,
        'isWeakHint': false,
      },
    );
    final caps = await platform.getCapabilities();
    expect(caps.canReadCurrent, isTrue);
    expect(caps.requiresFocusedTextField, isTrue);
    expect(caps.canSetLanguage, isFalse);
    expect(KeyboardLanguageCapabilities.fromMap(caps.toMap()), caps);
  });

  test('watch forwards native events and poll interval', () async {
    Object? listenArguments;
    var cancelled = false;
    messenger.setMockStreamHandler(
      MethodChannelKeyboardLanguage.eventChannel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          listenArguments = arguments;
          sink.success(<String, Object?>{
            'languageTag': 'en-US',
            'source': 'inputMethod',
          });
          sink.success(<String, Object?>{
            'languageTag': 'he-IL',
            'source': 'inputMethod',
          });
          sink.success(null);
        },
        onCancel: (arguments) => cancelled = true,
      ),
    );
    final events = <InputLanguage?>[];
    final sub = platform
        .watch(pollInterval: const Duration(milliseconds: 250))
        .listen(events.add);
    await pumpEventQueue();
    expect(listenArguments, <String, Object>{'pollIntervalMs': 250});
    expect(events.map((e) => e?.languageTag), <String?>[
      'en-US',
      'he-IL',
      null,
    ]);
    expect(events[1]!.isRtl, isTrue);
    await sub.cancel();
    await pumpEventQueue();
    expect(cancelled, isTrue);
  });
}
