import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'lang.dart';

/// Charts rendered via fl_chart (Task 6 migration) plus the extra charts
/// that have no fl_chart equivalent (Heatmap, Funnel, CalendarHeatmap),
/// which stay self-drawn. Every widget takes the theme palette explicitly
/// so [OpenUIThemeData.chartPalette] threads through all of them.

const _defaultPalette = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.red];

Color _colorAt(List<Color> palette, int i) => palette.isEmpty ? _defaultPalette[i % _defaultPalette.length] : palette[i % palette.length];

List<double> _seriesValues(ElementNode series) {
  return ((series.props['values'] as List?) ?? const []).map((e) => (e as num?)?.toDouble() ?? 0).toList();
}

/// Legend row used by every fl_chart widget in this file: a swatch
/// Container per series (the colour test in controller_theme_test pins
/// this exact shape) plus the series label.
class FlLegend extends StatelessWidget {
  const FlLegend({required this.labels, required this.palette});
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
        Expanded(child: chart),
        if (legend != null) legend,
      ],
    ),
  );
}

FlTitlesData _categoryTitles(List<String> categories, {bool show = true}) {
  if (!show) return FlTitlesData(show: false);
  return FlTitlesData(
    show: true,
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 22,
        getTitlesWidget: (value, meta) {
          final i = value.toInt();
          if (i < 0 || i >= categories.length) return const SizedBox.shrink();
          return SideTitleWidget(meta: meta, child: Text(categories[i], style: const TextStyle(fontSize: 10, color: Colors.grey)));
        },
      ),
    ),
  );
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

// ---------------- Bar / line / area / horizontal bar ----------------

class FlBarChartWidget extends StatelessWidget {
  const FlBarChartWidget({required this.categories, required this.series, this.palette = _defaultPalette, this.height = 220, this.showLegend = true, this.horizontal = false, this.stacked = false});
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
    final groups = <BarChartGroupData>[];
    for (var ci = 0; ci < categories.length; ci++) {
      if (stacked) {
        var running = 0.0;
        final stack = <BarChartRodStackItem>[];
        for (var si = 0; si < series.length; si++) {
          final v = ci < all[si].length ? all[si][ci] : 0;
          stack.add(BarChartRodStackItem(running, running + v, _colorAt(palette, si)));
          running += v;
        }
        groups.add(BarChartGroupData(x: ci, barRods: [BarChartRodData(toY: running == 0 ? 1 : running, rodStackItems: stack, width: 16)]));
      } else {
        groups.add(BarChartGroupData(
          x: ci,
          barRods: [
            for (var si = 0; si < series.length; si++)
              BarChartRodData(toY: ci < all[si].length ? all[si][ci] : 0, color: _colorAt(palette, si), width: 16),
          ],
        ));
      }
    }
    return _chartBox(
      height: height,
      chart: BarChart(
        BarChartData(
          barGroups: groups,
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          titlesData: _categoryTitles(categories),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          rotationQuarterTurns: horizontal ? 1 : 0,
        ),
      ),
      legend: showLegend ? FlLegend(labels: [for (final s in series) s.stringOf('category')], palette: palette) : null,
    );
  }
}

class FlLineChartWidget extends StatelessWidget {
  const FlLineChartWidget({required this.categories, required this.series, this.palette = _defaultPalette, this.height = 220, this.showLegend = true, this.area = false, this.curved = false, this.step = false});
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
      chart: LineChart(
        LineChartData(
          lineBarsData: [
            for (var si = 0; si < series.length; si++)
              LineChartBarData(
                spots: [for (var ci = 0; ci < all[si].length; ci++) FlSpot(ci.toDouble(), all[si][ci])],
                color: _colorAt(palette, si),
                barWidth: 2,
                isCurved: curved,
                isStepLineChart: step,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(show: area, color: _colorAt(palette, si).withValues(alpha: 0.2)),
              ),
          ],
          minX: 0,
          maxX: math.max(1, categories.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          titlesData: _categoryTitles(categories),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(enabled: false),
        ),
      ),
      legend: showLegend ? FlLegend(labels: [for (final s in series) s.stringOf('category')], palette: palette) : null,
    );
  }
}

// ---------------- Pie ----------------

class FlPieChartWidget extends StatelessWidget {
  const FlPieChartWidget({required this.labels, required this.values, this.variant = 'pie', this.appearance = 'circular', this.palette = _defaultPalette});
  final List<String> labels;
  final List<double> values;
  final String variant;
  final String appearance;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    // Semi-circular: real sections plus a transparent section of the
    // same total, starting at 9 o'clock so the real sections cover
    // exactly the top half.
    final total = values.fold<double>(0, (a, b) => a + b);
    final semi = appearance == 'semiCircular';
    final sections = <PieChartSectionData>[
      for (var i = 0; i < labels.length; i++)
        PieChartSectionData(
          value: i < values.length ? values[i] : 0,
          color: _colorAt(palette, i),
          title: labels[i],
          titleStyle: const TextStyle(fontSize: 11, color: Colors.white),
        ),
      if (semi) PieChartSectionData(value: total == 0 ? 1 : total, color: Colors.transparent, title: '', showTitle: false),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: variant == 'donut' ? 40 : 0,
                startDegreeOffset: semi ? 180 : 0,
              ),
            ),
          ),
          for (var i = 0; i < labels.length; i++)
            Row(children: [Container(width: 10, height: 10, color: _colorAt(palette, i)), const SizedBox(width: 6), Text('${labels[i]} (${i < values.length ? values[i] : 0})')]),
        ],
      ),
    );
  }
}

// ---------------- Radar ----------------

class FlRadarChartWidget extends StatelessWidget {
  const FlRadarChartWidget({required this.categories, required this.series, this.palette = _defaultPalette});
  final List<String> categories;
  final List<ElementNode> series;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    // fl_chart asserts non-empty dataSets, so an empty series list
    // (e.g. a Query returning nothing) renders the bordered empty box
    // instead of crashing the whole render, mirroring the old painter's
    // early return.
    if (series.isEmpty) return _chartBox(height: 240, chart: const SizedBox.shrink());
    // fl_chart asserts at least 3 radar entries per data set. A 1- or
    // 2-axis radar is geometrically degenerate, so pad with zero
    // entries (and empty titles) rather than crashing.
    final axisCount = math.max(3, categories.length);
    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Expanded(
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  for (var si = 0; si < series.length; si++)
                    RadarDataSet(
                      dataEntries: [
                        for (var ci = 0; ci < axisCount; ci++) RadarEntry(value: ci < _seriesValues(series[si]).length ? _seriesValues(series[si])[ci] : 0),
                      ],
                      fillColor: _colorAt(palette, si).withValues(alpha: 0.25),
                      borderColor: _colorAt(palette, si),
                      borderWidth: 2,
                    ),
                ],
                getTitle: (index, angle) => RadarChartTitle(text: index < categories.length ? categories[index] : ''),
                radarShape: RadarShape.polygon,
              ),
            ),
          ),
          FlLegend(labels: [for (final s in series) s.stringOf('category')], palette: palette),
        ],
      ),
    );
  }
}

// ---------------- Radial (gauge rings) ----------------

class FlRadialChartWidget extends StatelessWidget {
  const FlRadialChartWidget({required this.labels, required this.values, this.palette = _defaultPalette});
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
            child: GaugeChart(
              GaugeChartData(
                minValue: 0,
                maxValue: maxV,
                startDegreeOffset: -90,
                sweepAngle: 360,
                defaultRingWidth: 10,
                rings: [
                  for (var i = 0; i < labels.length; i++)
                    GaugeProgressRing(
                      value: i < values.length ? values[i] : 0,
                      color: _colorAt(palette, i),
                      backgroundColor: Colors.grey.shade200,
                      strokeCap: StrokeCap.round,
                    ),
                ],
              ),
            ),
          ),
          for (var i = 0; i < labels.length; i++)
            Row(children: [Container(width: 10, height: 10, color: _colorAt(palette, i)), const SizedBox(width: 6), Text('${labels[i]} (${i < values.length ? values[i] : 0})')]),
        ],
      ),
    );
  }
}

// ---------------- Single stacked bar ----------------

class FlStackedBarWidget extends StatelessWidget {
  const FlStackedBarWidget({required this.labels, required this.values, this.palette = _defaultPalette});
  final List<String> labels;
  final List<double> values;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    final total = values.fold<double>(0, (a, b) => a + b);
    var running = 0.0;
    final stack = <BarChartRodStackItem>[];
    for (var i = 0; i < labels.length; i++) {
      final v = i < values.length ? values[i] : 0;
      stack.add(BarChartRodStackItem(running, running + v, _colorAt(palette, i)));
      running += v;
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: BarChart(
              BarChartData(
                barGroups: [BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: total == 0 ? 1 : total, rodStackItems: stack, width: 24)])],
                alignment: BarChartAlignment.center,
                maxY: total == 0 ? 1 : total,
                titlesData: FlTitlesData(show: false),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
              ),
            ),
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

// ---------------- Scatter ----------------

class FlScatterChartWidget extends StatelessWidget {
  const FlScatterChartWidget({required this.series, this.palette = _defaultPalette});
  final List<ElementNode> series;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    final spots = <ScatterSpot>[];
    var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
    for (var si = 0; si < series.length; si++) {
      for (final p in series[si].nodesOf('points')) {
        final x = p.numOf('x');
        final y = p.numOf('y');
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
        spots.add(ScatterSpot(x, y, dotPainter: FlDotCirclePainter(radius: 6, color: _colorAt(palette, si))));
      }
    }
    if (spots.isEmpty) {
      minX = 0;
      maxX = 1;
      minY = 0;
      maxY = 1;
    }
    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Expanded(
            child: ScatterChart(
              ScatterChartData(
                scatterSpots: spots,
                minX: minX,
                maxX: maxX == minX ? minX + 1 : maxX,
                minY: minY,
                maxY: maxY == minY ? minY + 1 : maxY,
                titlesData: FlTitlesData(show: false),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                scatterTouchData: ScatterTouchData(enabled: false),
              ),
            ),
          ),
          FlLegend(labels: [for (final s in series) s.stringOf('name')], palette: palette),
        ],
      ),
    );
  }
}

// ---------------- Heatmap (self-drawn: no fl_chart equivalent) ----------------

class HeatmapChartWidget extends StatelessWidget {
  const HeatmapChartWidget({required this.categories, required this.series, this.palette = _defaultPalette});
  final List<String> categories;
  final List<ElementNode> series;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    final all = [for (final s in series) _seriesValues(s)];
    var maxV = 1.0;
    for (final list in all) {
      for (final v in list) {
        maxV = math.max(maxV, v);
      }
    }
    final base = _colorAt(palette, 0);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 56),
              for (final c in categories) Expanded(child: Center(child: Text(c, style: const TextStyle(fontSize: 11, color: Colors.grey)))),
            ],
          ),
          for (var si = 0; si < series.length; si++)
            Row(
              children: [
                SizedBox(width: 56, child: Text(series[si].stringOf('category'), style: const TextStyle(fontSize: 11))),
                for (var ci = 0; ci < categories.length; ci++)
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        color: base.withValues(alpha: 0.15 + 0.85 * ((ci < all[si].length ? all[si][ci] : 0) / maxV)),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------- Funnel (self-drawn: no fl_chart equivalent) ----------------

class _TrapezoidClipper extends CustomClipper<Path> {
  const _TrapezoidClipper({required this.topFraction, required this.bottomFraction});
  final double topFraction;
  final double bottomFraction;
  @override
  Path getClip(Size size) {
    final topW = size.width * topFraction;
    final bottomW = size.width * bottomFraction;
    return Path()
      ..moveTo((size.width - topW) / 2, 0)
      ..lineTo((size.width + topW) / 2, 0)
      ..lineTo((size.width + bottomW) / 2, size.height)
      ..lineTo((size.width - bottomW) / 2, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _TrapezoidClipper old) => old.topFraction != topFraction || old.bottomFraction != bottomFraction;
}

class FunnelChartWidget extends StatelessWidget {
  const FunnelChartWidget({required this.slices, this.palette = _defaultPalette});
  final List<ElementNode> slices;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    final maxV = slices.fold<double>(1, (m, s) => math.max(m, s.numOf('value')));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          for (var i = 0; i < slices.length; i++)
            Row(
              children: [
                Expanded(
                  child: ClipPath(
                    clipper: _TrapezoidClipper(
                      topFraction: (slices[i].numOf('value') / maxV).clamp(0.1, 1.0),
                      bottomFraction: (i + 1 < slices.length ? slices[i + 1].numOf('value') / maxV : slices[i].numOf('value') / maxV).clamp(0.1, 1.0),
                    ),
                    child: Container(height: 36, color: _colorAt(palette, i)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 110, child: Text('${slices[i].stringOf('category')} (${slices[i].numOf('value')})', style: const TextStyle(fontSize: 12))),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------- Calendar heatmap (self-drawn: no fl_chart equivalent) ----------------

class CalendarHeatmapWidget extends StatelessWidget {
  const CalendarHeatmapWidget({required this.values, this.palette = _defaultPalette});
  final List<Map<String, Object?>> values;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    // Bucket each date into its Monday-start week; columns are weeks,
    // rows are weekdays (Mon..Sun). Only parsing + weekday are used.
    final byDate = <DateTime, double>{};
    for (final entry in values) {
      final dateRaw = entry['date'];
      final valueRaw = entry['value'];
      if (dateRaw is! String || valueRaw is! num) continue;
      final parsed = DateTime.tryParse(dateRaw);
      if (parsed != null) byDate[DateTime(parsed.year, parsed.month, parsed.day)] = valueRaw.toDouble();
    }
    var maxV = 1.0;
    for (final v in byDate.values) {
      maxV = math.max(maxV, v);
    }
    final base = _colorAt(palette, 0);
    if (byDate.isEmpty) return const SizedBox.shrink();
    final dates = byDate.keys.toList()..sort();
    final weeks = <DateTime, List<double?>>{};
    for (final d in dates) {
      final monday = d.subtract(Duration(days: d.weekday - 1));
      final week = weeks.putIfAbsent(monday, () => List<double?>.filled(7, null));
      week[d.weekday - 1] = byDate[d];
    }
    final orderedWeeks = weeks.keys.toList()..sort();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final monday in orderedWeeks)
            Column(
              children: [
                for (var wd = 0; wd < 7; wd++)
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.all(2),
                    color: weeks[monday]![wd] == null ? Colors.grey.shade200 : base.withValues(alpha: 0.15 + 0.85 * (weeks[monday]![wd]! / maxV)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------- Mini charts (fl_chart, no axes/legend) ----------------

class MiniBarChartWidget extends StatelessWidget {
  const MiniBarChartWidget({required this.values, this.palette = _defaultPalette});
  final List<double> values;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    final maxY = _maxValue([values]);
    return SizedBox(
      height: 48,
      child: BarChart(
        BarChartData(
          barGroups: [for (var i = 0; i < values.length; i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: values[i], color: _colorAt(palette, 0), width: 8)])],
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          titlesData: FlTitlesData(show: false),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
        ),
      ),
    );
  }
}

class MiniLineChartWidget extends StatelessWidget {
  const MiniLineChartWidget({required this.values, this.palette = _defaultPalette});
  final List<double> values;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    final maxY = _maxValue([values]);
    return SizedBox(
      height: 48,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
              color: _colorAt(palette, 0),
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
          minX: 0,
          maxX: math.max(1, values.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          titlesData: FlTitlesData(show: false),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(enabled: false),
        ),
      ),
    );
  }
}

// ---------------- Stacked legend (swatches only, no chart area) ----------------

class StackedLegendWidget extends StatelessWidget {
  const StackedLegendWidget({required this.series, this.palette = _defaultPalette});
  final List<ElementNode> series;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    return FlLegend(labels: [for (final s in series) s.stringOf('category')], palette: palette);
  }
}
