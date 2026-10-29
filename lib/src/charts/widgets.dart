part of openui_charts;

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
