import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'lang.dart';

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

const _defaultPalette = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.red];

Color _colorAt(List<Color> palette, int i) => palette.isEmpty ? _defaultPalette[i % _defaultPalette.length] : palette[i % palette.length];

List<double> _seriesValues(ElementNode series) {
  return ((series.props['values'] as List?) ?? const []).map((e) => (e as num?)?.toDouble() ?? 0).toList();
}

double _maxValue(List<List<double>> all) {
  var m = 1.0;
  for (final list in all) {
    for (final v in list) {
      m = math.max(m, v);
    }
  }
  return m;
}

const _axisStyle = TextStyle(fontSize: 10, color: Colors.grey);

/// Legend row used by every chart widget in this file: a swatch
/// Container per series (the colour test in controller_theme_test
/// pins this exact shape) plus the series label.
class ChartLegend extends StatelessWidget {
  const ChartLegend({required this.labels, required this.palette});
  final List<String> labels;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        for (var i = 0; i < labels.length; i++)
          Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: _colorAt(palette, i)), const SizedBox(width: 4), Text(labels[i])]),
      ],
    );
  }
}

Widget _chartBox({required double height, required Widget chart, Widget? legend}) {
  return Container(
    height: height,
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
    child: Column(
      children: [
        // SizedBox.expand: a bare CustomPaint sizes to zero under the
        // Column's loose cross-axis constraints; the old fl_chart
        // widgets expanded on their own, so this was never needed.
        Expanded(child: SizedBox.expand(child: chart)),
        if (legend != null) legend,
      ],
    ),
  );
}

void _paintCenteredText(Canvas canvas, String text, Offset center, {double fontSize = 10, Color color = Colors.grey}) {
  final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color)), textDirection: TextDirection.ltr)..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

/// A bottom-axis category label, centered on [centerX] and centered
/// vertically in a 22px-tall label area starting at [areaTop].
/// A bar rect with the top (vertical) end rounded, like the old
/// fl_chart rods. [radius] caps at half the bar thickness.
void _drawBarTop(Canvas canvas, Rect rect, Paint paint, {bool horizontal = false}) {
  const radius = 6.0;
  final r = horizontal ? math.min(radius, rect.height / 2) : math.min(radius, rect.width / 2);
  final corners = horizontal
      ? RRect.fromRectAndCorners(rect, topRight: Radius.circular(r), bottomRight: Radius.circular(r))
      : RRect.fromRectAndCorners(rect, topLeft: Radius.circular(r), topRight: Radius.circular(r));
  canvas.drawRRect(corners, paint);
}

void _paintCategoryLabel(Canvas canvas, String text, double centerX, double areaTop, double maxWidth) {
  final tp = TextPainter(text: TextSpan(text: text, style: _axisStyle), textDirection: TextDirection.ltr, ellipsis: '…')..layout(maxWidth: maxWidth);
  tp.paint(canvas, Offset(centerX - tp.width / 2, areaTop + (22 - tp.height) / 2));
}

// ---------------- Bar / horizontal bar ----------------

class _BarPainter extends CustomPainter {
  _BarPainter({required this.categories, required this.all, required this.palette, required this.maxY, required this.stacked, required this.horizontal});
  final List<String> categories;
  final List<List<double>> all;
  final List<Color> palette;
  final double maxY;
  final bool stacked;
  final bool horizontal;

  @override
  void paint(Canvas canvas, Size size) {
    if (categories.isEmpty || size.width <= 0 || size.height <= 0) return;
    if (horizontal) {
      _paintHorizontal(canvas, size);
    } else {
      _paintVertical(canvas, size);
    }
  }

  void _paintVertical(Canvas canvas, Size size) {
    final plotH = size.height - 22;
    final n = categories.length;
    final slot = size.width / n;
    final m = all.length;
    for (var ci = 0; ci < n; ci++) {
      final x0 = ci * slot;
      if (stacked) {
        final rodW = math.min(16.0, slot);
        final cx = x0 + (slot - rodW) / 2;
        var running = 0.0;
        // Only the topmost segment gets the rounded top.
        var topSi = -1;
        for (var si = 0; si < m; si++) {
          if (ci < all[si].length && all[si][ci] > 0) topSi = si;
        }
        for (var si = 0; si < m; si++) {
          final v = ci < all[si].length ? all[si][ci] : 0;
          if (v > 0) {
            final top = plotH * (1 - (running + v) / maxY);
            final bottom = plotH * (1 - running / maxY);
            final rect = Rect.fromLTWH(cx, top, rodW, bottom - top);
            final paint = Paint()..color = _colorAt(palette, si);
            if (si == topSi) {
              _drawBarTop(canvas, rect, paint);
            } else {
              canvas.drawRect(rect, paint);
            }
          }
          running += v;
        }
      } else {
        final rodW = m == 0 ? 0.0 : math.min(16.0, slot / m);
        final startX = x0 + (slot - rodW * m) / 2;
        for (var si = 0; si < m; si++) {
          final v = ci < all[si].length ? all[si][ci] : 0;
          if (v > 0) {
            final h = plotH * v / maxY;
            _drawBarTop(canvas, Rect.fromLTWH(startX + si * rodW, plotH - h, rodW, h), Paint()..color = _colorAt(palette, si));
          }
        }
      }
      _paintCategoryLabel(canvas, categories[ci], x0 + slot / 2, plotH, slot);
    }
  }

  void _paintHorizontal(Canvas canvas, Size size) {
    final n = categories.length;
    var labelW = 0.0;
    for (final c in categories) {
      final tp = TextPainter(text: TextSpan(text: c, style: _axisStyle), textDirection: TextDirection.ltr)..layout();
      labelW = math.max(labelW, tp.width);
    }
    // Labels stay horizontal and readable; cap their column so a
    // long label cannot eat the whole bar area.
    final labelArea = math.min(labelW, size.width * 0.4 - 8);
    final barX = labelArea + 8;
    final barW = size.width - barX;
    if (barW <= 0) return;
    final slot = size.height / n;
    final m = all.length;
    for (var ci = 0; ci < n; ci++) {
      final y0 = ci * slot;
      final tp = TextPainter(text: TextSpan(text: categories[ci], style: _axisStyle), textDirection: TextDirection.ltr, ellipsis: '…')..layout(maxWidth: labelArea);
      tp.paint(canvas, Offset(barX - 8 - tp.width, y0 + (slot - tp.height) / 2));
      if (stacked) {
        final thick = math.min(16.0, slot);
        final cy = y0 + (slot - thick) / 2;
        var running = 0.0;
        // Only the rightmost segment gets the rounded end.
        var endSi = -1;
        for (var si = 0; si < m; si++) {
          if (ci < all[si].length && all[si][ci] > 0) endSi = si;
        }
        for (var si = 0; si < m; si++) {
          final v = ci < all[si].length ? all[si][ci] : 0;
          if (v > 0) {
            final rect = Rect.fromLTWH(barX + barW * running / maxY, cy, barW * v / maxY, thick);
            final paint = Paint()..color = _colorAt(palette, si);
            if (si == endSi) {
              _drawBarTop(canvas, rect, paint, horizontal: true);
            } else {
              canvas.drawRect(rect, paint);
            }
          }
          running += v;
        }
      } else {
        final thick = m == 0 ? 0.0 : math.min(16.0, slot / m);
        final startY = y0 + (slot - thick * m) / 2;
        for (var si = 0; si < m; si++) {
          final v = ci < all[si].length ? all[si][ci] : 0;
          if (v > 0) {
            _drawBarTop(canvas, Rect.fromLTWH(barX, startY + si * thick, barW * v / maxY, thick), Paint()..color = _colorAt(palette, si), horizontal: true);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------- Line / area ----------------

class _LinePainter extends CustomPainter {
  _LinePainter({required this.categories, required this.all, required this.palette, required this.maxY, required this.area, required this.curved, required this.step});
  final List<String> categories;
  final List<List<double>> all;
  final List<Color> palette;
  final double maxY;
  final bool area;
  final bool curved;
  final bool step;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final plotH = size.height - 22;
    final n = categories.length;
    final denom = math.max(1, n - 1);
    double px(int ci) => size.width * ci / denom;
    double py(double v) => plotH * (1 - v / maxY);
    for (var si = 0; si < all.length; si++) {
      final vals = all[si];
      if (vals.isEmpty) continue;
      final pts = [for (var ci = 0; ci < vals.length; ci++) Offset(px(ci), py(vals[ci]))];
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      if (curved && pts.length > 2) {
        // Catmull-Rom to Bezier: a smooth curve through the points,
        // the same shape class as the old curved line chart.
        for (var i = 0; i < pts.length - 1; i++) {
          final p0 = i == 0 ? pts[i] : pts[i - 1];
          final p1 = pts[i];
          final p2 = pts[i + 1];
          final p3 = i + 2 < pts.length ? pts[i + 2] : pts[i + 1];
          path.cubicTo(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6, p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6, p2.dx, p2.dy);
        }
      } else if (step) {
        for (var i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i - 1].dy);
          path.lineTo(pts[i].dx, pts[i].dy);
        }
      } else {
        for (var i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
      }
      final color = _colorAt(palette, si);
      if (area) {
        final fill = Path.from(path)
          ..lineTo(pts.last.dx, plotH)
          ..lineTo(pts.first.dx, plotH)
          ..close();
        canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.2));
      }
      canvas.drawPath(path, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      for (final p in pts) {
        canvas.drawCircle(p, 4, Paint()..color = color);
      }
    }
    for (var ci = 0; ci < n; ci++) {
      _paintCategoryLabel(canvas, categories[ci], px(ci), plotH, size.width / denom);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------- Pie ----------------

class _PiePainter extends CustomPainter {
  _PiePainter({required this.labels, required this.values, required this.variant, required this.appearance, required this.palette});
  final List<String> labels;
  final List<double> values;
  final String variant;
  final String appearance;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0 || labels.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(size.width, size.height) / 2 - 4;
    if (outerR <= 0) return;
    final donut = variant == 'donut';
    final semi = appearance == 'semiCircular';
    // Circular starts at 3 o'clock, semi-circular at 9 o'clock so
    // the real sections cover exactly the top half.
    final fullSweep = semi ? math.pi : math.pi * 2;
    var angle = semi ? math.pi : 0.0;
    final gap = 2 / outerR; // ~2px arc gap between sections.
    for (var i = 0; i < labels.length; i++) {
      final v = i < values.length ? values[i] : 0;
      final sweep = v / total * fullSweep;
      if (sweep <= 0) continue;
      final inset = math.min(gap / 2, sweep / 2);
      final a0 = angle + inset;
      final a1 = angle + sweep - inset;
      if (a1 > a0) {
        if (donut && outerR > 42) {
          final midR = (outerR + 40) / 2;
          canvas.drawArc(Rect.fromCircle(center: center, radius: midR), a0, a1 - a0, false, Paint()
            ..color = _colorAt(palette, i)
            ..style = PaintingStyle.stroke
            ..strokeWidth = outerR - 40);
        } else {
          final path = Path()
            ..moveTo(center.dx, center.dy)
            ..arcTo(Rect.fromCircle(center: center, radius: outerR), a0, a1 - a0, false)
            ..close();
          canvas.drawPath(path, Paint()..color = _colorAt(palette, i));
        }
      }
      // Section title, white on the slice; skipped for slivers
      // where it could never be readable.
      if (sweep >= 0.25) {
        final mid = angle + sweep / 2;
        final r = donut && outerR > 42 ? (outerR + 40) / 2 : outerR * 0.65;
        _paintCenteredText(canvas, labels[i], center + Offset(math.cos(mid) * r, math.sin(mid) * r), fontSize: 11, color: Colors.white);
      }
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------- Radar ----------------

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.categories, required this.all, required this.palette, required this.maxV});
  final List<String> categories;
  final List<List<double>> all;
  final List<Color> palette;
  final double maxV;

  @override
  void paint(Canvas canvas, Size size) {
    final n = categories.length;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 24;
    if (n == 0 || radius <= 0) return;
    Offset vertex(int i, double r) {
      final angle = -math.pi / 2 + i * math.pi * 2 / n;
      return center + Offset(math.cos(angle) * r, math.sin(angle) * r);
    }

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (n >= 3) {
      for (final f in [0.25, 0.5, 0.75, 1.0]) {
        final path = Path();
        for (var i = 0; i < n; i++) {
          final p = vertex(i, radius * f);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, gridPaint);
      }
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, vertex(i, radius), gridPaint);
    }
    for (var i = 0; i < n; i++) {
      _paintCenteredText(canvas, categories[i], vertex(i, radius + 14), fontSize: 11);
    }
    // Values scale relative to the largest entry, so the biggest
    // value always reaches the outer ring; all-zero data sits at
    // the center.
    final scale = maxV > 0 ? radius / maxV : 0.0;
    for (var si = 0; si < all.length; si++) {
      final vals = all[si];
      double val(int i) => i < vals.length ? vals[i] : 0;
      final color = _colorAt(palette, si);
      if (n == 1) {
        canvas.drawCircle(vertex(0, val(0) * scale), 3, Paint()..color = color);
      } else if (n == 2) {
        // Geometrically degenerate: a line between the two values,
        // not a padded triangle.
        final a = vertex(0, val(0) * scale);
        final b = vertex(1, val(1) * scale);
        canvas.drawLine(a, b, Paint()
          ..color = color
          ..strokeWidth = 2);
        canvas.drawCircle(a, 3, Paint()..color = color);
        canvas.drawCircle(b, 3, Paint()..color = color);
      } else {
        final path = Path();
        for (var i = 0; i < n; i++) {
          final p = vertex(i, val(i) * scale);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.25));
        canvas.drawPath(path, Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------- Radial (gauge rings) ----------------

class _RadialPainter extends CustomPainter {
  _RadialPainter({required this.values, required this.palette, required this.maxV});
  final List<double> values;
  final List<Color> palette;
  final double maxV;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(size.width, size.height) / 2 - 8;
    for (var i = 0; i < values.length; i++) {
      final r = outerR - i * 16;
      if (r <= 5) break;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), 0, math.pi * 2, false, Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10);
      final v = i < values.length ? values[i] : 0;
      if (v > 0 && maxV > 0) {
        canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, v / maxV * math.pi * 2, false, Paint()
          ..color = _colorAt(palette, i)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------- Single stacked bar ----------------

class _StackedBarPainter extends CustomPainter {
  _StackedBarPainter({required this.values, required this.palette, required this.total});
  final List<double> values;
  final List<Color> palette;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    const colW = 24.0;
    final x = (size.width - colW) / 2;
    var y = size.height;
    var topI = -1;
    for (var i = 0; i < values.length; i++) {
      if (values[i] > 0) topI = i;
    }
    for (var i = 0; i < values.length; i++) {
      final h = size.height * values[i] / total;
      if (h > 0) {
        y -= h;
        final rect = Rect.fromLTWH(x, y, colW, h);
        final paint = Paint()..color = _colorAt(palette, i);
        if (i == topI) {
          _drawBarTop(canvas, rect, paint);
        } else {
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------- Scatter ----------------

/// One scatter dot in data coordinates, with its bubble radius
/// already resolved.
typedef ScatterDot = ({double x, double y, double radius, int seriesIndex});

/// The scatter layout in data coordinates: dots plus the axis
/// bounds the painter maps from.
typedef ScatterLayout = ({List<ScatterDot> dots, double minX, double maxX, double minY, double maxY});

/// Pure data step of the scatter chart, kept separate from the
/// painter so tests can pin the bubble radii without a widget.
/// A point's z scales its bubble (area proportional to z, as in a
/// bubble chart); points without z keep the default radius.
ScatterLayout computeScatterLayout(List<ElementNode> series) {
  final raw = <({double x, double y, double? z, int si})>[];
  var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity, maxZ = 0.0;
  for (var si = 0; si < series.length; si++) {
    for (final p in series[si].nodesOf('points')) {
      final x = p.numOf('x');
      final y = p.numOf('y');
      final z = p.props['z'] is num ? (p.props['z'] as num).toDouble() : null;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      if (z != null) maxZ = math.max(maxZ, z);
      raw.add((x: x, y: y, z: z, si: si));
    }
  }
  final dots = <ScatterDot>[
    for (final p in raw) (x: p.x, y: p.y, radius: p.z == null ? 6 : (maxZ > 0 ? 4 + 8 * math.sqrt(p.z! / maxZ) : 4), seriesIndex: p.si),
  ];
  if (dots.isEmpty) {
    minX = 0;
    maxX = 1;
    minY = 0;
    maxY = 1;
  }
  return (dots: dots, minX: minX, maxX: maxX == minX ? minX + 1 : maxX, minY: minY, maxY: maxY == minY ? minY + 1 : maxY);
}

class _ScatterPainter extends CustomPainter {
  _ScatterPainter({required this.layout, required this.palette});
  final ScatterLayout layout;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final spanX = layout.maxX - layout.minX;
    final spanY = layout.maxY - layout.minY;
    for (final d in layout.dots) {
      final px = (d.x - layout.minX) / spanX * size.width;
      final py = size.height - (d.y - layout.minY) / spanY * size.height;
      canvas.drawCircle(Offset(px, py), d.radius, Paint()..color = _colorAt(palette, d.seriesIndex));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------- Widgets ----------------

class BarChartWidget extends StatelessWidget {
  const BarChartWidget({required this.categories, required this.series, this.palette = _defaultPalette, this.height = 220, this.showLegend = true, this.horizontal = false, this.stacked = false});
  final List<String> categories;
  final List<ElementNode> series;
  final List<Color> palette;
  final double height;
  final bool showLegend;
  final bool horizontal;
  final bool stacked;
  @override
  Widget build(BuildContext context) {
    final all = [for (final s in series) _seriesValues(s)];
    var stackedMax = 1.0;
    if (stacked) {
      for (var ci = 0; ci < categories.length; ci++) {
        var sum = 0.0;
        for (var si = 0; si < series.length; si++) {
          sum += ci < all[si].length ? all[si][ci] : 0;
        }
        if (sum > stackedMax) stackedMax = sum;
      }
    }
    final maxY = stacked ? stackedMax : _maxValue(all);
    return _chartBox(
      height: height,
      chart: CustomPaint(painter: _BarPainter(categories: categories, all: all, palette: palette, maxY: maxY, stacked: stacked, horizontal: horizontal)),
      legend: showLegend ? ChartLegend(labels: [for (final s in series) s.stringOf('category')], palette: palette) : null,
    );
  }
}

class LineChartWidget extends StatelessWidget {
  const LineChartWidget({required this.categories, required this.series, this.palette = _defaultPalette, this.height = 220, this.showLegend = true, this.area = false, this.curved = false, this.step = false});
  final List<String> categories;
  final List<ElementNode> series;
  final List<Color> palette;
  final double height;
  final bool showLegend;
  final bool area;
  final bool curved;
  final bool step;
  @override
  Widget build(BuildContext context) {
    final all = [for (final s in series) _seriesValues(s)];
    final maxY = _maxValue(all);
    return _chartBox(
      height: height,
      chart: CustomPaint(painter: _LinePainter(categories: categories, all: all, palette: palette, maxY: maxY, area: area, curved: curved, step: step)),
      legend: showLegend ? ChartLegend(labels: [for (final s in series) s.stringOf('category')], palette: palette) : null,
    );
  }
}

class PieChartWidget extends StatelessWidget {
  const PieChartWidget({required this.labels, required this.values, this.variant = 'pie', this.appearance = 'circular', this.palette = _defaultPalette});
  final List<String> labels;
  final List<double> values;
  final String variant;
  final String appearance;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(painter: _PiePainter(labels: labels, values: values, variant: variant, appearance: appearance, palette: palette)),
          ),
          for (var i = 0; i < labels.length; i++)
            Row(children: [Container(width: 10, height: 10, color: _colorAt(palette, i)), const SizedBox(width: 6), Text('${labels[i]} (${i < values.length ? values[i] : 0})')]),
        ],
      ),
    );
  }
}

class RadarChartWidget extends StatelessWidget {
  const RadarChartWidget({required this.categories, required this.series, this.palette = _defaultPalette});
  final List<String> categories;
  final List<ElementNode> series;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    // An empty series list (e.g. a Query returning nothing) renders
    // the bordered empty box instead of crashing the whole render.
    if (series.isEmpty) return _chartBox(height: 240, chart: const SizedBox.shrink());
    final all = [for (final s in series) _seriesValues(s)];
    var maxV = 0.0;
    for (final list in all) {
      for (final v in list) {
        maxV = math.max(maxV, v);
      }
    }
    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Expanded(
            child: SizedBox.expand(child: CustomPaint(painter: _RadarPainter(categories: categories, all: all, palette: palette, maxV: maxV))),
          ),
          ChartLegend(labels: [for (final s in series) s.stringOf('category')], palette: palette),
        ],
      ),
    );
  }
}

class RadialChartWidget extends StatelessWidget {
  const RadialChartWidget({required this.labels, required this.values, this.palette = _defaultPalette});
  final List<String> labels;
  final List<double> values;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(1, (m, v) => math.max(m, v));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(painter: _RadialPainter(values: values, palette: palette, maxV: maxV)),
          ),
          for (var i = 0; i < labels.length; i++)
            Row(children: [Container(width: 10, height: 10, color: _colorAt(palette, i)), const SizedBox(width: 6), Text('${labels[i]} (${i < values.length ? values[i] : 0})')]),
        ],
      ),
    );
  }
}

class SingleStackedBarWidget extends StatelessWidget {
  const SingleStackedBarWidget({required this.labels, required this.values, this.palette = _defaultPalette});
  final List<String> labels;
  final List<double> values;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final padded = [for (var i = 0; i < labels.length; i++) i < values.length ? values[i] : 0.0];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: CustomPaint(painter: _StackedBarPainter(values: padded, palette: palette, total: total)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [for (var i = 0; i < labels.length; i++) Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: _colorAt(palette, i)), const SizedBox(width: 4), Text('${labels[i]} (${total == 0 ? 0 : ((i < values.length ? values[i] : 0) / total * 100).round()}%)')])],
          ),
        ],
      ),
    );
  }
}

class ScatterChartWidget extends StatelessWidget {
  const ScatterChartWidget({required this.series, this.palette = _defaultPalette});
  final List<ElementNode> series;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Expanded(
            child: SizedBox.expand(child: CustomPaint(painter: _ScatterPainter(layout: computeScatterLayout(series), palette: palette))),
          ),
          ChartLegend(labels: [for (final s in series) s.stringOf('name')], palette: palette),
        ],
      ),
    );
  }
}
