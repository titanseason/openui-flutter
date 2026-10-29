part of openui_charts;

// ---------------- Axes: nice domains, grid, ticks ----------------
//
// React parity: cartesian charts show a Y axis and horizontal grid
// by default, the Y domain always runs through zero, negatives
// render, and ticks are d3-style nice numbers (~1 per 40px of plot
// height, floored at 2). The painters and the tooltip hit tests
// share these pure functions, so a hover slot and the painted
// grid can never disagree.

/// A value domain plus its tick positions.
typedef YDomain = ({double min, double max, List<double> ticks});

/// d3-style nice domain: [dataMin, dataMax] widened to round tick
/// boundaries. [throughZero] pins the domain to include zero (the
/// React cartesian rule); scatter axes pass false. [pixelsPerTick]
/// sets the target tick density (40 for value axes, 60 for the
/// wider bottom labels).
YDomain niceDomain(double dataMin, double dataMax, double plotSize, {bool throughZero = true, double pixelsPerTick = 40}) {
  var lo = throughZero ? math.min(0, dataMin) : dataMin;
  var hi = throughZero ? math.max(0, dataMax) : dataMax;
  if (lo == hi) hi = lo + 1;
  final target = math.max(2, (plotSize / pixelsPerTick).floor());
  final span = hi - lo;
  var step = math.pow(10, (math.log(span / target) / math.ln10).floorToDouble()).toDouble();
  final err = (span / target) / step;
  if (err >= math.sqrt(50)) {
    step *= 10;
  } else if (err >= math.sqrt(10)) {
    step *= 5;
  } else if (err >= math.sqrt(2)) {
    step *= 2;
  }
  final niceMin = (lo / step).floor() * step;
  final niceMax = (hi / step).ceil() * step;
  final count = ((niceMax - niceMin) / step).round();
  return (min: niceMin, max: niceMax, ticks: [for (var i = 0; i <= count; i++) niceMin + i * step]);
}

/// Raw data bounds over every series, hidden or not, so toggling
/// a legend entry never rescales the chart (the Phase 1 rule).
({double min, double max}) minMaxOf(List<List<double>> all) {
  var lo = double.infinity, hi = -double.infinity;
  for (final list in all) {
    for (final v in list) {
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
  }
  if (lo == double.infinity) return (min: 0.0, max: 0.0);
  return (min: lo, max: hi);
}

/// Stacked bounds: per category, positives stack up and negatives
/// stack down (React's sign offset), so the domain covers the
/// largest positive stack and the deepest negative stack.
({double min, double max}) stackedMinMax(List<List<double>> all, int n) {
  var lo = 0.0, hi = 0.0;
  for (var ci = 0; ci < n; ci++) {
    var pos = 0.0, neg = 0.0;
    for (final list in all) {
      final v = ci < list.length ? list[ci] : 0;
      if (v > 0) {
        pos += v;
      } else if (v < 0) {
        neg += v;
      }
    }
    lo = math.min(lo, neg);
    hi = math.max(hi, pos);
  }
  return (min: lo, max: hi);
}

/// Left width reserved for Y tick labels: the widest label plus a
/// gap, measured with the same style the painter uses.
double axisWidthForTicks(List<double> ticks) {
  if (ticks.isEmpty) return 0;
  var w = 0.0;
  for (final t in ticks) {
    final tp = TextPainter(text: TextSpan(text: _fmtNum(t), style: _axisStyle), textDirection: TextDirection.ltr)..layout();
    w = math.max(w, tp.width);
  }
  return w + 8;
}

/// Maps a value to a y pixel inside a plot of height [plotH]
/// (0 is the top).
double yForValue(double v, YDomain domain, double plotH) {
  final span = domain.max - domain.min;
  if (span <= 0) return plotH;
  return plotH * (domain.max - v) / span;
}

/// Plot geometry for a vertical cartesian chart: the nice domain,
/// the left axis width, and the plot size (bottom 22px reserved
/// for category labels).
typedef CartesianPlot = ({YDomain domain, double axisW, double plotW, double plotH});

CartesianPlot cartesianPlot({required double dataMin, required double dataMax, required Size size, double bottomLabels = 22}) {
  final plotH = math.max(0.0, size.height - bottomLabels);
  final domain = niceDomain(dataMin, dataMax, plotH);
  final axisW = axisWidthForTicks(domain.ticks);
  return (domain: domain, axisW: axisW, plotW: math.max(0.0, size.width - axisW), plotH: plotH);
}

/// Y axis line, horizontal gridlines, and right-aligned tick
/// labels. Gridlines span the plot only, starting at the axis.
void _paintAxisTicks(Canvas canvas, YDomain domain, double axisW, double plotW, double plotH) {
  final gridPaint = Paint()
    ..color = Colors.grey.shade200
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final axisPaint = Paint()
    ..color = Colors.grey.shade300
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  canvas.drawLine(Offset(axisW, 0), Offset(axisW, plotH), axisPaint);
  for (final t in domain.ticks) {
    final y = yForValue(t, domain, plotH);
    canvas.drawLine(Offset(axisW, y), Offset(axisW + plotW, y), gridPaint);
    final tp = TextPainter(text: TextSpan(text: _fmtNum(t), style: _axisStyle), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(axisW - 4 - tp.width, y - tp.height / 2));
  }
}

/// Bottom value axis (horizontal bars, scatter X): vertical
/// gridlines plus labels in the 22px strip below the plot.
/// [barX] is the plot's left edge, [barW] its width.
void _paintValueTicksBottom(Canvas canvas, YDomain domain, double barX, double barW, double plotH) {
  final gridPaint = Paint()
    ..color = Colors.grey.shade200
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  double xOf(double v) => barX + barW * (v - domain.min) / (domain.max - domain.min);
  for (final t in domain.ticks) {
    final x = xOf(t);
    canvas.drawLine(Offset(x, 0), Offset(x, plotH), gridPaint);
    _paintCategoryLabel(canvas, _fmtNum(t), x, plotH, 60);
  }
}
