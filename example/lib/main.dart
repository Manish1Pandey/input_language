import 'dart:async';

import 'package:flutter/material.dart';
import 'package:keyboard_language/keyboard_language.dart';

void main() => runApp(const KeyboardLanguageDemoApp());

/// Demo of every keyboard_language feature.
class KeyboardLanguageDemoApp extends StatelessWidget {
  /// Creates the demo app.
  const KeyboardLanguageDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'keyboard_language',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

/// The single demo screen.
class DemoPage extends StatefulWidget {
  /// Creates the demo screen.
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  InputLanguage? _current;
  KeyboardLanguageCapabilities? _capabilities;
  List<InputLanguage> _available = const <InputLanguage>[];
  final List<String> _log = <String>[];
  StreamSubscription<InputLanguage?>? _subscription;
  AutoDirectionPolicy _policy = AutoDirectionPolicy.keyboardThenText;
  String? _setResult;

  final TextEditingController _builderController = TextEditingController();
  final TextEditingController _bidiController = TextEditingController(
    text: '123 שלום world',
  );

  @override
  void initState() {
    super.initState();
    _subscription = KeyboardLanguage.onChanged.listen(
      (language) => setState(() {
        _current = language;
        _log.insert(0, '${_time()}  ${_describe(language)}');
        if (_log.length > 20) _log.removeLast();
      }),
      onError: (Object error) =>
          setState(() => _log.insert(0, 'error: $error')),
    );
    _refresh();
  }

  Future<void> _refresh() async {
    final results = await Future.wait<Object?>(<Future<Object?>>[
      KeyboardLanguage.current,
      KeyboardLanguage.capabilities(),
      KeyboardLanguage.available(),
    ]);
    if (!mounted) return;
    setState(() {
      _current = results[0] as InputLanguage?;
      _capabilities = results[1] as KeyboardLanguageCapabilities;
      _available = results[2] as List<InputLanguage>;
    });
  }

  Future<void> _select(InputLanguage language) async {
    String message;
    try {
      final ok = await KeyboardLanguage.setLanguage(language.languageTag);
      message = ok
          ? 'Switched to ${language.languageTag}'
          : 'No installed keyboard matches ${language.languageTag}';
    } on UnsupportedError catch (e) {
      message = 'Unsupported: ${e.message}';
    }
    if (!mounted) return;
    setState(() => _setResult = message);
    await _refresh();
  }

  static String _time() => DateTime.now().toIso8601String().substring(11, 19);

  static String _describe(InputLanguage? language) {
    if (language == null) return 'unknown (null)';
    return '${language.languageTag} · ${language.isRtl ? 'RTL' : 'LTR'} · '
        '${language.source.name}'
        '${language.displayName == null ? '' : ' · ${language.displayName}'}';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _builderController.dispose();
    _bidiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caps = _capabilities;
    return Scaffold(
      appBar: AppBar(
        title: const Text('keyboard_language'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _Section(
            title: 'Current keyboard language',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_describe(_current), style: theme.textTheme.titleMedium),
                if (_current?.inputSourceId != null)
                  Text(
                    'OS id: ${_current!.inputSourceId}',
                    style: theme.textTheme.bodySmall,
                  ),
                if (caps?.requiresFocusedTextField ?? false)
                  const Text(
                    'On this platform the value is only known while a text '
                    'field is focused — tap a field below.',
                  ),
                if (caps?.isWeakHint ?? false)
                  const Text(
                    'On the web this is only the browser language; typed '
                    'text decides the direction.',
                  ),
              ],
            ),
          ),
          _Section(
            title: 'AutoDirectionTextField',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SegmentedButton<AutoDirectionPolicy>(
                  segments: const <ButtonSegment<AutoDirectionPolicy>>[
                    ButtonSegment(
                      value: AutoDirectionPolicy.keyboardThenText,
                      label: Text('Keyboard→text'),
                    ),
                    ButtonSegment(
                      value: AutoDirectionPolicy.textThenKeyboard,
                      label: Text('Text→keyboard'),
                    ),
                    ButtonSegment(
                      value: AutoDirectionPolicy.textOnly,
                      label: Text('Text only'),
                    ),
                  ],
                  selected: <AutoDirectionPolicy>{_policy},
                  onSelectionChanged: (s) => setState(() => _policy = s.first),
                ),
                const SizedBox(height: 12),
                AutoDirectionTextField(
                  key: const Key('auto-field'),
                  policy: _policy,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Type in any language',
                    hintText: 'Switch keyboards — direction follows',
                  ),
                  onDirectionChanged: (direction, keyboard) => setState(
                    () => _log.insert(
                      0,
                      'field direction → ${direction.name} '
                      '(keyboard: ${keyboard?.languageTag ?? 'unknown'})',
                    ),
                  ),
                ),
              ],
            ),
          ),
          _Section(
            title: 'AutoDirectionBuilder + TextFormField',
            child: AutoDirectionBuilder(
              controller: _builderController,
              policy: AutoDirectionPolicy.textThenKeyboard,
              builder: (context, direction, focusNode) => TextFormField(
                controller: _builderController,
                focusNode: focusNode,
                textDirection: direction,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Message (${direction.name})',
                ),
              ),
            ),
          ),
          _Section(
            title: 'Bidi first-strong detection (Unicode $kBidiUnicodeVersion)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _bidiController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Text(
                  'detectTextDirection → '
                  '${detectTextDirection(_bidiController.text)?.name ?? 'null (no strong character)'}',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children:
                      <String>[
                            'שלום',
                            'مرحبا',
                            'سلام',
                            'آپ کیسے ہیں',
                            'ܫܠܡܐ',
                            'ދ\u07A8ވ\u07ACހ\u07A8',
                            'ߒߞߏ',
                            '١٢٣ hello',
                          ]
                          .map(
                            (sample) => ActionChip(
                              label: Text(sample),
                              onPressed: () =>
                                  setState(() => _bidiController.text = sample),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Enabled keyboards · setLanguage',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  caps == null
                      ? ''
                      : caps.canSetLanguage
                      ? 'Tap a keyboard to switch to it.'
                      : 'This platform does not let apps switch keyboards; '
                            'tapping shows the UnsupportedError.',
                ),
                const SizedBox(height: 8),
                if (_available.isEmpty) const Text('No list available.'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _available
                      .map(
                        (language) => ActionChip(
                          avatar: Icon(
                            language.isRtl
                                ? Icons.format_textdirection_r_to_l
                                : Icons.format_textdirection_l_to_r,
                            size: 18,
                          ),
                          label: Text(
                            language.displayName ?? language.languageTag,
                          ),
                          onPressed: () => _select(language),
                        ),
                      )
                      .toList(),
                ),
                if (_setResult != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(_setResult!),
                ],
              ],
            ),
          ),
          _Section(
            title: 'Capabilities',
            child: Text(
              caps == null
                  ? 'loading…'
                  : caps
                        .toMap()
                        .entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n'),
            ),
          ),
          _Section(
            title: 'onChanged log',
            child: Text(_log.isEmpty ? 'No events yet.' : _log.join('\n')),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
