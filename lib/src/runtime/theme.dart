import 'package:flutter/material.dart';

import '../core/lang.dart';

/// The semantic colours a component needs. The first three are the
/// core (accent, background, text on that background); the rest
/// default to the previously hardcoded values, so a scheme built
/// with only the core three looks exactly as before:
/// - [textMuted] is secondary text: chart axis labels and empty
///   states (was `Colors.grey`, 0xFF9E9E9E).
/// - [border] is the default border: chart boxes, axis lines,
///   tooltip cards (was `grey.shade300`, 0xFFE0E0E0).
/// - [grid] is chart gridlines and track backgrounds (was
///   `grey.shade200`, 0xFFEEEEEE).
/// - [success]/[warning]/[danger]/[info] are Callout variant
///   colours (were green/orange/red/blue); a neutral Callout uses
///   [textMuted].
/// Charts use [OpenUIThemeData.chartPalette] for series colours;
/// these fields are the chart chrome around them.
class OpenUIColorScheme {
  const OpenUIColorScheme({
    required this.primary,
    required this.surface,
    required this.onSurface,
    this.textMuted = const Color(0xFF9E9E9E),
    this.border = const Color(0xFFE0E0E0),
    this.grid = const Color(0xFFEEEEEE),
    this.success = Colors.green,
    this.warning = Colors.orange,
    this.danger = Colors.red,
    this.info = Colors.blue,
  });
  final Color primary;
  final Color surface;
  final Color onSurface;
  final Color textMuted;
  final Color border;
  final Color grid;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
}

/// Visual theme for the renderer. Hosts pass one to [OpenUIController];
/// the renderer reads it from the controller in controller mode and
/// otherwise uses [OpenUIThemeData.light]. Builders are injection
/// points: when supplied, the renderer uses them instead of its
/// built-in skeleton / error views.
class OpenUIThemeData {
  const OpenUIThemeData({
    required this.colors,
    required this.chartPalette,
    this.cardRadius = 12,
    this.skeletonBuilder,
    this.errorBuilder,
  });
  final OpenUIColorScheme colors;
  final List<Color> chartPalette;
  final double cardRadius;
  final WidgetBuilder? skeletonBuilder;
  final Widget Function(BuildContext context, OpenUIError error)? errorBuilder;

  static OpenUIThemeData light() {
    return const OpenUIThemeData(
      colors: OpenUIColorScheme(primary: Colors.blue, surface: Colors.white, onSurface: Colors.black87),
      chartPalette: [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.red],
    );
  }

  static OpenUIThemeData dark() {
    // Dark chrome is lighter than the light defaults: the old
    // hardcoded light greys left dark charts with faint labels
    // and washed-out gridlines.
    return const OpenUIThemeData(
      colors: OpenUIColorScheme(
        primary: Colors.lightBlue,
        surface: Color(0xFF121212),
        onSurface: Colors.white,
        textMuted: Color(0xFFBDBDBD),
        border: Color(0xFF424242),
        grid: Color(0xFF303030),
        success: Colors.lightGreen,
        warning: Colors.orange,
        danger: Colors.redAccent,
        info: Colors.lightBlue,
      ),
      chartPalette: [Colors.lightBlue, Colors.lightGreen, Colors.orange, Colors.purple, Colors.teal, Colors.red],
    );
  }
}
