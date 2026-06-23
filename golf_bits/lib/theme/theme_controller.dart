import 'package:flutter/material.dart';

/// App-wide light/dark control. Wraps [MaterialApp]; read it via
/// [ThemeController.maybeOf] to flip the theme from Profile. Defaults to dark
/// ("on course"); light ("in the clubhouse") only when the user selects it.
class ThemeController extends InheritedWidget {
  const ThemeController({
    super.key,
    required this.mode,
    required this.setMode,
    required super.child,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> setMode;

  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeController>();

  @override
  bool updateShouldNotify(ThemeController oldWidget) => oldWidget.mode != mode;
}
