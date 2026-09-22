import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'direction.dart';
import 'input_language.dart';

/// Signature of [AutoDirectionBuilder.builder].
///
/// Pass [direction] to your field's `textDirection` and [focusNode] to its
/// `focusNode` (it is the node you gave the builder, or one it created).
typedef AutoDirectionWidgetBuilder =
    Widget Function(
      BuildContext context,
      TextDirection direction,
      FocusNode focusNode,
    );

/// Rebuilds any text field (`TextField`, `TextFormField`, `CupertinoTextField`,
/// `EditableText`) with the direction resolved from the keyboard language and
/// the typed text.
///
/// ```dart
/// AutoDirectionBuilder(
///   controller: controller,
///   builder: (context, direction, focusNode) => TextFormField(
///     controller: controller,
///     focusNode: focusNode,
///     textDirection: direction,
///   ),
/// )
/// ```
class AutoDirectionBuilder extends StatefulWidget {
  /// Creates an auto-direction builder.
  const AutoDirectionBuilder({
    super.key,
    required this.controller,
    required this.builder,
    this.focusNode,
    this.policy = AutoDirectionPolicy.keyboardThenText,
    this.fallback,
    this.keyboardOnlyWhileFocused = true,
    this.onDirectionChanged,
  });

  /// The field's text controller.
  final TextEditingController controller;

  /// Builds the field; see [AutoDirectionWidgetBuilder].
  final AutoDirectionWidgetBuilder builder;

  /// The field's focus node; one is created and disposed when omitted.
  final FocusNode? focusNode;

  /// How keyboard language and typed text are combined.
  final AutoDirectionPolicy policy;

  /// Direction when nothing decides; defaults to the ambient
  /// [Directionality], or [TextDirection.ltr] when there is none.
  final TextDirection? fallback;

  /// See [KeyboardDirectionController.keyboardOnlyWhileFocused].
  final bool keyboardOnlyWhileFocused;

  /// Called whenever the resolved direction changes, with the keyboard
  /// language that was current at that moment.
  final void Function(TextDirection direction, InputLanguage? keyboard)?
  onDirectionChanged;

  @override
  State<AutoDirectionBuilder> createState() => _AutoDirectionBuilderState();
}

class _AutoDirectionBuilderState extends State<AutoDirectionBuilder> {
  FocusNode? _ownFocusNode;
  KeyboardDirectionController? _direction;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  TextDirection _fallback(BuildContext context) =>
      widget.fallback ?? Directionality.maybeOf(context) ?? TextDirection.ltr;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final direction = _direction;
    if (direction == null) {
      _create();
    } else {
      direction.fallback = _fallback(context);
    }
  }

  void _create() {
    _direction?.removeListener(_changed);
    _direction?.dispose();
    _direction = KeyboardDirectionController(
      textController: widget.controller,
      focusNode: _focusNode,
      policy: widget.policy,
      fallback: _fallback(context),
      keyboardOnlyWhileFocused: widget.keyboardOnlyWhileFocused,
    )..addListener(_changed);
  }

  @override
  void didUpdateWidget(AutoDirectionBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode && widget.focusNode != null) {
      _ownFocusNode?.dispose();
      _ownFocusNode = null;
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.focusNode != widget.focusNode ||
        oldWidget.keyboardOnlyWhileFocused != widget.keyboardOnlyWhileFocused) {
      _create();
    } else {
      _direction!
        ..policy = widget.policy
        ..fallback = _fallback(context);
    }
  }

  void _changed() {
    final direction = _direction!;
    widget.onDirectionChanged?.call(
      direction.value,
      direction.keyboardLanguage,
    );
    setState(() {});
  }

  @override
  void dispose() {
    _direction?.removeListener(_changed);
    _direction?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _direction!.value, _focusNode);
}

/// A Material [TextField] whose `textDirection` follows the active keyboard
/// language, falling back to the first strong character of the typed text.
///
/// For parameters not exposed here, use [AutoDirectionBuilder] with your own
/// field.
class AutoDirectionTextField extends StatefulWidget {
  /// Creates an auto-direction text field.
  const AutoDirectionTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.style,
    this.textAlign = TextAlign.start,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.readOnly = false,
    this.enabled,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.policy = AutoDirectionPolicy.keyboardThenText,
    this.fallback,
    this.keyboardOnlyWhileFocused = true,
    this.onDirectionChanged,
  });

  /// Text controller; one is created and disposed when omitted.
  final TextEditingController? controller;

  /// Focus node; one is created and disposed when omitted.
  final FocusNode? focusNode;

  /// See [TextField.decoration].
  final InputDecoration? decoration;

  /// See [TextField.style].
  final TextStyle? style;

  /// See [TextField.textAlign]. The default `start` follows the resolved
  /// direction.
  final TextAlign textAlign;

  /// See [TextField.keyboardType].
  final TextInputType? keyboardType;

  /// See [TextField.textInputAction].
  final TextInputAction? textInputAction;

  /// See [TextField.textCapitalization].
  final TextCapitalization textCapitalization;

  /// See [TextField.autofocus].
  final bool autofocus;

  /// See [TextField.obscureText].
  final bool obscureText;

  /// See [TextField.autocorrect].
  final bool autocorrect;

  /// See [TextField.enableSuggestions].
  final bool enableSuggestions;

  /// See [TextField.readOnly].
  final bool readOnly;

  /// See [TextField.enabled].
  final bool? enabled;

  /// See [TextField.maxLines].
  final int? maxLines;

  /// See [TextField.minLines].
  final int? minLines;

  /// See [TextField.maxLength].
  final int? maxLength;

  /// See [TextField.inputFormatters].
  final List<TextInputFormatter>? inputFormatters;

  /// See [TextField.onChanged].
  final ValueChanged<String>? onChanged;

  /// See [TextField.onEditingComplete].
  final VoidCallback? onEditingComplete;

  /// See [TextField.onSubmitted].
  final ValueChanged<String>? onSubmitted;

  /// See [AutoDirectionBuilder.policy].
  final AutoDirectionPolicy policy;

  /// See [AutoDirectionBuilder.fallback].
  final TextDirection? fallback;

  /// See [KeyboardDirectionController.keyboardOnlyWhileFocused].
  final bool keyboardOnlyWhileFocused;

  /// See [AutoDirectionBuilder.onDirectionChanged].
  final void Function(TextDirection direction, InputLanguage? keyboard)?
  onDirectionChanged;

  @override
  State<AutoDirectionTextField> createState() => _AutoDirectionTextFieldState();
}

class _AutoDirectionTextFieldState extends State<AutoDirectionTextField> {
  TextEditingController? _ownController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void didUpdateWidget(AutoDirectionTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && _ownController != null) {
      // The child builder still listens to the old controller until it
      // rebuilds; dispose it after this frame.
      final stale = _ownController!;
      _ownController = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => stale.dispose());
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return AutoDirectionBuilder(
      controller: controller,
      focusNode: widget.focusNode,
      policy: widget.policy,
      fallback: widget.fallback,
      keyboardOnlyWhileFocused: widget.keyboardOnlyWhileFocused,
      onDirectionChanged: widget.onDirectionChanged,
      builder: (context, direction, focusNode) => TextField(
        controller: controller,
        focusNode: focusNode,
        textDirection: direction,
        decoration: widget.decoration,
        style: widget.style,
        textAlign: widget.textAlign,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        autofocus: widget.autofocus,
        obscureText: widget.obscureText,
        autocorrect: widget.autocorrect,
        enableSuggestions: widget.enableSuggestions,
        readOnly: widget.readOnly,
        enabled: widget.enabled,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        onEditingComplete: widget.onEditingComplete,
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
