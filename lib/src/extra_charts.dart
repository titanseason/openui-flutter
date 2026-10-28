import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'lang.dart';

/// Charts rendered via fl_chart. Every widget takes the theme palette
/// explicitly so [OpenUIThemeData.chartPalette] threads through all
/// of them.

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
    // First pass: bounds and the largest z. A point's z scales its
    // bubble (area proportional to z, as in a bubble chart); points
    // without z keep the default radius.
    final points = <({double x, double y, double? z, int si})>[];
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
        points.add((x: x, y: y, z: z, si: si));
      }
    }
    final spots = <ScatterSpot>[
      for (final p in points)
        ScatterSpot(
          p.x,
          p.y,
          dotPainter: FlDotCirclePainter(
            radius: p.z == null ? 6 : (maxZ > 0 ? 4 + 8 * math.sqrt(p.z! / maxZ) : 4),
            color: _colorAt(palette, p.si),
          ),
        ),
    ];
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

