part of openui_charts;

// ---------------- Widgets ----------------
//
// Every widget wraps its paint area in a [_HoverArea] (mouse hover
// + touch drag tooltip, React parity) and makes its legend
// tappable to hide/show series or slices — except the single
// stacked bar, whose React counterpart has no legend toggle.

class BarChartWidget extends StatefulWidget {
  const BarChartWidget({required this.categories, required this.series, this.palette = _defaultPalette, this.height = 220, this.showLegend = true, this.horizontal = false, this.stacked = false});
  final List<String> categories;
  final List<ElementNode> series;
  final List<Color> palette;
  final double height;
  final bool showLegend;
  final bool horizontal;
  final bool stacked;
  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget> with _LegendToggle<BarChartWidget> {
  @override
  Widget build(BuildContext context) {
    final all = [for (final s in widget.series) _seriesValues(s)];
    return _chartBox(
      height: widget.height,
      chart: _HoverArea(
        onHover: (pos, area) {
          final int ci;
          if (widget.horizontal) {
            // Rows fill the plot; the bottom 22px are the value axis.
            ci = _categoryAtY(pos.dy, area.height - 22, widget.categories.length);
          } else {
            final mm = widget.stacked ? stackedMinMax(all, widget.categories.length) : minMaxOf(all);
            final plot = cartesianPlot(dataMin: mm.min, dataMax: mm.max, size: area);
            ci = _categoryAtX(pos.dx, plot.axisW, plot.plotW, widget.categories.length);
          }
          if (ci < 0) return null;
          final rows = <TipRow>[];
          for (var si = 0; si < widget.series.length; si++) {
            if (hidden.contains(si)) continue;
            rows.add((label: widget.series[si].stringOf('category'), value: _fmtNum(ci < all[si].length ? all[si][ci] : 0), color: _colorAt(widget.palette, si)));
          }
          return (title: widget.categories[ci], rows: rows);
        },
        builder: (context, hoverPos, _) => CustomPaint(painter: _BarPainter(categories: widget.categories, all: all, palette: widget.palette, stacked: widget.stacked, horizontal: widget.horizontal, hidden: hidden, hoverPos: hoverPos)),
      ),
      legend: widget.showLegend ? ChartLegend(labels: [for (final s in widget.series) s.stringOf('category')], palette: widget.palette, hidden: hidden, onToggle: toggleLegend) : null,
    );
  }
}

class LineChartWidget extends StatefulWidget {
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
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget> with _LegendToggle<LineChartWidget> {
  @override
  Widget build(BuildContext context) {
    final all = [for (final s in widget.series) _seriesValues(s)];
    return _chartBox(
      height: widget.height,
      chart: _HoverArea(
        onHover: (pos, area) {
          final mm = minMaxOf(all);
          final plot = cartesianPlot(dataMin: mm.min, dataMax: mm.max, size: area);
          final ci = _lineCategoryAtX(pos.dx, plot.axisW, plot.plotW, widget.categories.length);
          if (ci < 0) return null;
          final rows = <TipRow>[];
          for (var si = 0; si < widget.series.length; si++) {
            if (hidden.contains(si)) continue;
            rows.add((label: widget.series[si].stringOf('category'), value: _fmtNum(ci < all[si].length ? all[si][ci] : 0), color: _colorAt(widget.palette, si)));
          }
          return (title: widget.categories[ci], rows: rows);
        },
        builder: (context, hoverPos, _) => CustomPaint(painter: _LinePainter(categories: widget.categories, all: all, palette: widget.palette, area: widget.area, curved: widget.curved, step: widget.step, hidden: hidden, hoverPos: hoverPos)),
      ),
      legend: widget.showLegend ? ChartLegend(labels: [for (final s in widget.series) s.stringOf('category')], palette: widget.palette, hidden: hidden, onToggle: toggleLegend) : null,
    );
  }
}

class PieChartWidget extends StatefulWidget {
  const PieChartWidget({required this.labels, required this.values, this.variant = 'pie', this.appearance = 'circular', this.palette = _defaultPalette});
  final List<String> labels;
  final List<double> values;
  final String variant;
  final String appearance;
  final List<Color> palette;
  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget> with _LegendToggle<PieChartWidget> {
  int? _legendHovered;

  @override
  Widget build(BuildContext context) {
    // Shared by the tooltip hit test and the hover dim: the painter
    // re-normalizes over the visible slices, so the hit test runs
    // on the same filtered values.
    int? pieHit(Offset pos, Size area) {
      final visible = <int>[for (var i = 0; i < widget.labels.length; i++) if (!hidden.contains(i)) i];
      final vals = [for (final i in visible) i < widget.values.length ? widget.values[i] : 0.0];
      final hit = widget.appearance == 'semiCircular' ? _semiPieSliceAt(pos, area, vals) : _pieSliceAt(pos, area, vals);
      if (hit < 0) return null;
      return visible[hit];
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: _HoverArea(
              onHover: (pos, area) {
                final i = pieHit(pos, area);
                if (i == null) return null;
                final v = i < widget.values.length ? widget.values[i] : 0.0;
                return (
                  title: widget.labels[i],
                  rows: [(label: widget.labels[i], value: _fmtNum(v), color: _colorAt(widget.palette, i))],
                );
              },
              builder: (context, hoverPos, area) => CustomPaint(painter: _PiePainter(labels: widget.labels, values: widget.values, variant: widget.variant, appearance: widget.appearance, palette: widget.palette, hidden: hidden, hovered: _legendHovered ?? (hoverPos == null ? null : pieHit(hoverPos, area)))),
            ),
          ),
          _StackedLegend(labels: widget.labels, values: widget.values, palette: widget.palette, hidden: hidden, onToggle: toggleLegend, onHover: (i) => setState(() => _legendHovered = i)),
        ],
      ),
    );
  }
}

class RadarChartWidget extends StatefulWidget {
  const RadarChartWidget({required this.categories, required this.series, this.palette = _defaultPalette});
  final List<String> categories;
  final List<ElementNode> series;
  final List<Color> palette;
  @override
  State<RadarChartWidget> createState() => _RadarChartWidgetState();
}

class _RadarChartWidgetState extends State<RadarChartWidget> with _LegendToggle<RadarChartWidget> {
  @override
  Widget build(BuildContext context) {
    // An empty series list (e.g. a Query returning nothing) renders
    // the bordered empty box instead of crashing the whole render.
    if (widget.series.isEmpty) return _chartBox(height: 240, chart: const SizedBox.shrink());
    final all = [for (final s in widget.series) _seriesValues(s)];
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
            child: SizedBox.expand(
              child: _HoverArea(
                onHover: (pos, area) {
                  final axis = _radarAxisAt(pos, area, widget.categories.length);
                  if (axis < 0) return null;
                  final rows = <TipRow>[];
                  for (var si = 0; si < widget.series.length; si++) {
                    if (hidden.contains(si)) continue;
                    rows.add((label: widget.series[si].stringOf('category'), value: _fmtNum(axis < all[si].length ? all[si][axis] : 0), color: _colorAt(widget.palette, si)));
                  }
                  return (title: widget.categories[axis], rows: rows);
                },
                builder: (context, _, __) => CustomPaint(painter: _RadarPainter(categories: widget.categories, all: all, palette: widget.palette, maxV: maxV, hidden: hidden)),
              ),
            ),
          ),
          ChartLegend(labels: [for (final s in widget.series) s.stringOf('category')], palette: widget.palette, hidden: hidden, onToggle: toggleLegend),
        ],
      ),
    );
  }
}

class RadialChartWidget extends StatefulWidget {
  const RadialChartWidget({required this.labels, required this.values, this.palette = _defaultPalette});
  final List<String> labels;
  final List<double> values;
  final List<Color> palette;
  @override
  State<RadialChartWidget> createState() => _RadialChartWidgetState();
}

class _RadialChartWidgetState extends State<RadialChartWidget> with _LegendToggle<RadialChartWidget> {
  int? _legendHovered;

  @override
  Widget build(BuildContext context) {
    final maxV = widget.values.fold<double>(1, (m, v) => math.max(m, v));
    // Rings keep their index-based radii when hidden, so the hit
    // index is already the original one.
    int? ringHit(Offset pos, Size area) {
      final hit = _radialRingAt(pos, area, widget.labels.length);
      if (hit < 0 || hidden.contains(hit)) return null;
      return hit;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: _HoverArea(
              onHover: (pos, area) {
                final hit = ringHit(pos, area);
                if (hit == null) return null;
                final v = hit < widget.values.length ? widget.values[hit] : 0.0;
                return (
                  title: widget.labels[hit],
                  rows: [(label: widget.labels[hit], value: _fmtNum(v), color: _colorAt(widget.palette, hit))],
                );
              },
              builder: (context, hoverPos, area) => CustomPaint(painter: _RadialPainter(values: widget.values, palette: widget.palette, maxV: maxV, hidden: hidden, hovered: _legendHovered ?? (hoverPos == null ? null : ringHit(hoverPos, area)))),
            ),
          ),
          _StackedLegend(labels: widget.labels, values: widget.values, palette: widget.palette, hidden: hidden, onToggle: toggleLegend, onHover: (i) => setState(() => _legendHovered = i)),
        ],
      ),
    );
  }
}

class SingleStackedBarWidget extends StatefulWidget {
  const SingleStackedBarWidget({required this.labels, required this.values, this.palette = _defaultPalette});
  final List<String> labels;
  final List<double> values;
  final List<Color> palette;
  @override
  State<SingleStackedBarWidget> createState() => _SingleStackedBarWidgetState();
}

class _SingleStackedBarWidgetState extends State<SingleStackedBarWidget> {
  // Hovering a legend row highlights its segment and dims the rest,
  // like React's SegmentedBar. (Track hover comes through the
  // _HoverArea builder, so the two never fight.)
  int? _legendHovered;

  @override
  Widget build(BuildContext context) {
    final total = widget.values.fold<double>(0, (a, b) => a + b);
    final padded = [for (var i = 0; i < widget.labels.length; i++) i < widget.values.length ? widget.values[i] : 0.0];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 20,
            child: _HoverArea(
              onHover: (pos, area) {
                final seg = _stackedSegmentAtX(pos.dx, area.width, padded, total);
                if (seg < 0) return null;
                final v = padded[seg];
                final pct = total == 0 ? 0.0 : v / total * 100;
                final color = _colorAt(widget.palette, seg);
                return (
                  title: widget.labels[seg],
                  rows: [(label: widget.labels[seg], value: _fmtNum(v), color: color), (label: 'Percentage', value: '${pct.toStringAsFixed(1)}%', color: color)],
                );
              },
              builder: (context, hoverPos, area) {
                final trackHovered = hoverPos == null ? null : _stackedSegmentAtX(hoverPos.dx, area.width, padded, total);
                return CustomPaint(painter: _StackedBarPainter(values: padded, palette: widget.palette, total: total, hoveredSegment: _legendHovered ?? trackHovered));
              },
            ),
          ),
          // React's gap between the bar and the DefaultLegend.
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              for (var i = 0; i < widget.labels.length; i++)
                MouseRegion(
                  onEnter: (_) => setState(() => _legendHovered = i),
                  onExit: (_) => setState(() => _legendHovered = null),
                  // No toggle and no dim on the row itself: React's
                  // SegmentedBar only hover-highlights.
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: _colorAt(widget.palette, i)), const SizedBox(width: 4), Text(widget.labels[i]), const SizedBox(width: 6), Text(total == 0 ? '0.0%' : '${(padded[i] / total * 100).toStringAsFixed(1)}%')]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ScatterChartWidget extends StatefulWidget {
  const ScatterChartWidget({required this.series, this.palette = _defaultPalette});
  final List<ElementNode> series;
  final List<Color> palette;
  @override
  State<ScatterChartWidget> createState() => _ScatterChartWidgetState();
}

class _ScatterChartWidgetState extends State<ScatterChartWidget> with _LegendToggle<ScatterChartWidget> {
  @override
  Widget build(BuildContext context) {
    final full = computeScatterLayout(widget.series);
    // Filter dots, not series: colours come from seriesIndex, so
    // they never shift when a dataset is hidden.
    final layout = (dots: [for (final d in full.dots) if (!hidden.contains(d.seriesIndex)) d], minX: full.minX, maxX: full.maxX, minY: full.minY, maxY: full.maxY);
    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Expanded(
            child: SizedBox.expand(
              child: _HoverArea(
                onHover: (pos, area) {
                  final plot = scatterPlotFor(layout, area);
                  final hit = _scatterDotAt(pos, plot, layout.dots);
                  if (hit < 0) return null;
                  final d = layout.dots[hit];
                  final color = _colorAt(widget.palette, d.seriesIndex);
                  return (
                    title: widget.series[d.seriesIndex].stringOf('name'),
                    rows: [(label: 'x', value: _fmtNum(d.x), color: color), (label: 'y', value: _fmtNum(d.y), color: color)],
                  );
                },
                builder: (context, _, __) => CustomPaint(painter: _ScatterPainter(layout: layout, palette: widget.palette)),
              ),
            ),
          ),
          ChartLegend(labels: [for (final s in widget.series) s.stringOf('name')], palette: widget.palette, hidden: hidden, onToggle: toggleLegend),
        ],
      ),
    );
  }
}
