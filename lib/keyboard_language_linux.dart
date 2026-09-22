/// Linux implementation of `keyboard_language` (best effort).
///
/// Reads the active input source from GNOME
/// (`gsettings get org.gnome.desktop.input-sources mru-sources`, whose first
/// entry is the current source) and otherwise from IBus (`ibus engine`).
/// Changes are observed with `gsettings monitor` on GNOME and by polling
/// `ibus engine` elsewhere. Returns `null` on desktops that use neither
/// (Fcitx, KDE without IBus, …). Switching the language is not supported.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'src/capabilities.dart';
import 'src/input_language.dart';
import 'src/linux_sources.dart';
import 'src/platform_interface.dart';

/// Runs a command to completion; injectable for tests.
typedef LinuxProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// Starts a long-running command; injectable for tests.
typedef LinuxProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

const String _schema = 'org.gnome.desktop.input-sources';

/// [KeyboardLanguagePlatform] for Linux desktops using GNOME and/or IBus.
class KeyboardLanguageLinux extends KeyboardLanguagePlatform {
  /// Creates the Linux implementation. [runProcess] and [startProcess]
  /// default to `Process.run` / `Process.start`.
  KeyboardLanguageLinux({
    LinuxProcessRunner? runProcess,
    LinuxProcessStarter? startProcess,
  }) : _run = runProcess ?? ((exe, args) => Process.run(exe, args)),
       _start = startProcess ?? ((exe, args) => Process.start(exe, args));

  /// Registers this class as the platform implementation.
  static void registerWith() {
    KeyboardLanguagePlatform.instance = KeyboardLanguageLinux();
  }

  final LinuxProcessRunner _run;
  final LinuxProcessStarter _start;

  Future<String?> _output(String executable, List<String> arguments) async {
    try {
      final result = await _run(executable, arguments);
      if (result.exitCode != 0) return null;
      final out = result.stdout;
      return out is String ? out.trim() : null;
    } on ProcessException {
      return null;
    }
  }

  Future<List<GnomeInputSource>?> _gnomeSources(String key) async {
    final out = await _output('gsettings', <String>['get', _schema, key]);
    if (out == null) return null;
    return parseGnomeInputSources(out);
  }

  Future<bool> _hasGnome() async {
    final sources = await _gnomeSources('sources');
    return sources != null && sources.isNotEmpty;
  }

  @override
  Future<InputLanguage?> getCurrent() async {
    final mru = await _gnomeSources('mru-sources');
    if (mru != null && mru.isNotEmpty) {
      return languageFromGnomeSource(mru.first);
    }
    final configured = await _gnomeSources('sources');
    if (configured != null && configured.isNotEmpty) {
      return languageFromGnomeSource(configured.first);
    }
    final engine = await _output('ibus', <String>['engine']);
    if (engine == null || engine.isEmpty) return null;
    return languageFromIbusEngine(engine);
  }

  @override
  Stream<InputLanguage?> watch({required Duration pollInterval}) {
    late final StreamController<InputLanguage?> controller;
    Process? monitor;
    StreamSubscription<String>? lines;
    Timer? poll;
    var cancelled = false;

    Future<void> emitCurrent() async {
      final language = await getCurrent();
      if (!cancelled) controller.add(language);
    }

    controller = StreamController<InputLanguage?>(
      onListen: () async {
        await emitCurrent();
        if (cancelled) return;
        if (await _hasGnome()) {
          try {
            final process = await _start('gsettings', <String>[
              'monitor',
              _schema,
              'mru-sources',
            ]);
            if (cancelled) {
              process.kill();
              return;
            }
            monitor = process;
            lines = process.stdout
                .transform(utf8.decoder)
                .transform(const LineSplitter())
                .listen((_) => emitCurrent());
            return;
          } on ProcessException {
            // Fall through to polling.
          }
        }
        if (cancelled) return;
        poll = Timer.periodic(pollInterval, (_) => emitCurrent());
      },
      onCancel: () async {
        cancelled = true;
        poll?.cancel();
        await lines?.cancel();
        monitor?.kill();
      },
    );
    return controller.stream;
  }

  @override
  Future<List<InputLanguage>> getAvailable() async {
    final sources = await _gnomeSources('sources');
    if (sources == null) return const <InputLanguage>[];
    final result = <InputLanguage>[];
    for (final source in sources) {
      final language = languageFromGnomeSource(source);
      if (language != null && !result.contains(language)) result.add(language);
    }
    return List<InputLanguage>.unmodifiable(result);
  }

  @override
  Future<bool> setLanguage(String languageTag) {
    throw UnsupportedError(
      'Switching the keyboard language is not supported on Linux.',
    );
  }

  @override
  Future<KeyboardLanguageCapabilities> getCapabilities() async {
    final gnome = await _hasGnome();
    final ibus = gnome
        ? false
        : (await _output('ibus', <String>['engine'])) != null;
    return KeyboardLanguageCapabilities(
      canReadCurrent: gnome || ibus,
      canObserveChanges: gnome || ibus,
      canListAvailable: gnome,
      canSetLanguage: false,
      requiresFocusedTextField: false,
      isWeakHint: false,
    );
  }
}
