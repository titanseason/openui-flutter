import 'package:flutter/material.dart';

import 'lang.dart';

/// The three colours a component needs: accent, background, and text on
/// that background. Charts use [OpenUIThemeData.chartPalette] instead.
class OpenUIColorScheme {
  const OpenUIColorScheme({required this.primary, required this.surface, required this.onSurface});
  final Color primary;
  final Color surface;
  final Color onSurface;
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
    return const OpenUIThemeData(
      colors: OpenUIColorScheme(primary: Colors.lightBlue, surface: Color(0xFF121212), onSurface: Colors.white),
      chartPalette: [Colors.lightBlue, Colors.lightGreen, Colors.orange, Colors.purple, Colors.teal, Colors.red],
    );
  }
}
