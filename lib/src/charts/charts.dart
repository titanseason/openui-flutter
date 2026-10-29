library openui_charts;

/// Charts drawn with [CustomPainter] and plain widgets — no chart
/// package. Every widget takes the theme palette explicitly so
/// [OpenUIThemeData.chartPalette] threads through all of them.
///
/// Kept identical to the old fl_chart rendering where it matters:
/// the legend shape (a 10x10 swatch plus a label), the legend text
/// formats ('label (value)' for pie/radial, 'label (xx%)' for the
/// stacked bar), the box heights, and the value scales (bar/line
/// maxY floors at 1.0, stacked bars scale by their stack sum).
/// Changed on purpose: HorizontalBar category titles are drawn
/// horizontal on the left instead of rotated (the old rotation
/// wrapped them letter by letter in narrow columns), and a 1- or
/// 2-axis radar draws its true geometry (a dot, a line) instead of
/// a padded triangle. Touch was already disabled on every chart,
/// so nothing interactive is lost.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../lang.dart';

part 'bar.dart';
part 'common.dart';
part 'line.dart';
part 'pie.dart';
part 'radar.dart';
part 'radial.dart';
part 'scatter.dart';
part 'stacked.dart';
part 'tooltip.dart';
part 'widgets.dart';
