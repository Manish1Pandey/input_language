import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:input_language/input_language.dart';
import 'package:input_language/input_language_linux.dart';
import 'package:input_language/src/linux_sources.dart';

void main() {
  group('parsing', () {
    test('GNOME input source lists', () {
      expect(
        parseGnomeInputSources("[('xkb', 'us'), ('ibus', 'm17n:ar:kbd')]"),
        <GnomeInputSource>[
          (type: 'xkb', id: 'us'),
          (type: 'ibus', id: 'm17n:ar:kbd'),
        ],
      );
      expect(parseGnomeInputSources('@a(ss) []'), isEmpty);
    });

    test('XKB layouts', () {
      expect(languageTagForXkbLayout('us'), 'en-US');
      expect(languageTagForXkbLayout('il'), 'he');
      expect(languageTagForXkbLayout('ara'), 'ar');
      expect(languageTagForXkbLayout('ir'), 'fa');
      expect(languageTagForXkbLayout('pk'), 'ur');
      expect(languageTagForXkbLayout('mv'), 'dv');
      expect(languageTagForXkbLayout('de+nodeadkeys'), 'de');
      expect(languageTagForXkbLayout('iq+ku_ara'), 'ckb');
      expect(languageTagForXkbLayout('in+urd-phonetic'), 'ur');
      expect(languageTagForXkbLayout('zz'), isNull);
    });

    test('IBus engines', () {
      expect(languageTagForIbusEngine('xkb:us::eng'), 'en-US');
      expect(languageTagForIbusEngine('xkb:il::heb'), 'he');
      expect(languageTagForIbusEngine('xkb:ir::per'), 'fa');
      expect(languageTagForIbusEngine('xkb:ara::ara'), 'ar');
      expect(languageTagForIbusEngine('m17n:ur:phonetic'), 'ur');
      expect(languageTagForIbusEngine('mozc-jp'), 'ja');
      expect(languageTagForIbusEngine('hangul'), 'ko');
      expect(languageTagForIbusEngine('table:cangjie5'), 'zh-Hant');
      expect(languageTagForIbusEngine('typing-booster'), isNull);
      expect(languageTagForIbusEngine(''), isNull);
      expect(languageTagForIso639('syr'), 'syr');
      expect(languageTagForIso639('fas'), 'fa');
    });

    test('InputLanguage conversion', () {
      final he = languageFromGnomeSource((type: 'xkb', id: 'il'))!;
      expect(he.isRtl, isTrue);
      expect(he.inputSourceId, 'xkb:il');
      expect(he.source, InputLanguageSource.keyboardLayout);
      expect(languageFromIbusEngine('xkb:us::eng\n')!.languageTag, 'en-US');
    });
  });

  group('KeyboardLanguageLinux', () {
    ProcessResult ok(String out) => ProcessResult(1, 0, out, '');
    ProcessResult fail() => ProcessResult(1, 1, '', 'No such schema');

    test('reads GNOME mru-sources first', () async {
      final linux = KeyboardLanguageLinux(
        runProcess: (exe, args) async {
          if (exe == 'gsettings' && args.last == 'mru-sources') {
            return ok("[('ibus', 'm17n:fa:isiri'), ('xkb', 'us')]\n");
          }
          if (exe == 'gsettings' && args.last == 'sources') {
            return ok(
              "[('xkb', 'us'), ('xkb', 'il'), ('ibus', 'm17n:fa:isiri')]",
            );
          }
          return fail();
        },
      );
      final current = await linux.getCurrent();
      expect(current!.languageTag, 'fa');
      expect(current.isRtl, isTrue);
      final available = await linux.getAvailable();
      expect(available.map((l) => l.languageTag), <String>[
        'en-US',
        'he',
        'fa',
      ]);
      final caps = await linux.getCapabilities();
      expect(caps.canReadCurrent, isTrue);
      expect(caps.canListAvailable, isTrue);
      expect(caps.canSetLanguage, isFalse);
      expect(() => linux.setLanguage('fa'), throwsUnsupportedError);
    });

    test('falls back to ibus engine, then null', () async {
      var ibus = 'xkb:il::heb\n';
      final linux = KeyboardLanguageLinux(
        runProcess: (exe, args) async {
          if (exe == 'gsettings') throw const ProcessException('gsettings', []);
          return ibus.isEmpty ? fail() : ok(ibus);
        },
      );
      expect((await linux.getCurrent())!.languageTag, 'he');
      expect(await linux.getAvailable(), isEmpty);
      ibus = '';
      expect(await linux.getCurrent(), isNull);
      final caps = await linux.getCapabilities();
      expect(caps.canReadCurrent, isFalse);
    });

    test('watch uses gsettings monitor on GNOME', () async {
      var mru = "[('xkb', 'us')]";
      final monitorOut = StreamController<List<int>>();
      final process = _FakeProcess(monitorOut.stream);
      List<String>? started;
      final linux = KeyboardLanguageLinux(
        runProcess: (exe, args) async =>
            ok(args.last == 'mru-sources' ? mru : "[('xkb', 'us')]"),
        startProcess: (exe, args) async {
          started = <String>[exe, ...args];
          return process;
        },
      );
      final events = <String?>[];
      final sub = linux
          .watch(pollInterval: const Duration(seconds: 1))
          .listen((l) => events.add(l?.languageTag));
      await pumpEventQueue();
      expect(started, <String>[
        'gsettings',
        'monitor',
        'org.gnome.desktop.input-sources',
        'mru-sources',
      ]);
      mru = "[('xkb', 'ara'), ('xkb', 'us')]";
      monitorOut.add(utf8.encode("mru-sources: [('xkb', 'ara')]\n"));
      await pumpEventQueue();
      expect(events, <String?>['en-US', 'ar']);
      await sub.cancel();
      expect(process.killed, isTrue);
      await monitorOut.close();
    });

    test('watch polls ibus without GNOME', () async {
      var engine = 'xkb:us::eng';
      final linux = KeyboardLanguageLinux(
        runProcess: (exe, args) async {
          if (exe == 'gsettings') return ProcessResult(1, 1, '', '');
          return ok(engine);
        },
      );
      final events = <String?>[];
      final sub = linux
          .watch(pollInterval: const Duration(milliseconds: 10))
          .listen((l) => events.add(l?.languageTag));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      engine = 'm17n:ar:kbd';
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await sub.cancel();
      expect(events.first, 'en-US');
      expect(events, contains('ar'));
    });
  });
}

class _FakeProcess implements Process {
  _FakeProcess(this.stdout);

  @override
  final Stream<List<int>> stdout;

  bool killed = false;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => killed = true;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  IOSink get stdin => throw UnsupportedError('stdin');

  @override
  int get pid => 1;

  @override
  Future<int> get exitCode => Future<int>.value(0);
}
