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

/// Y axis line, horizontal gridlines, and right-aligned tick
/// labels. Gridlines span the plot only, starting at the axis.
/// (Scatter keeps this combined painter: it never scrolls.)
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
/// gridlines plus labels in the strip below the plot.
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
    _paintWrappedLabel(canvas, _fmtNum(t), x, plotH, 60, 1);
  }
}

/// Y axis line plus right-aligned tick labels, without gridlines:
/// the fixed column beside a scrolling plot (the gridlines scroll
/// with the plot, so the plot painter draws them).
void _paintYAxis(Canvas canvas, YDomain domain, double axisW, double plotH) {
  final axisPaint = Paint()
    ..color = Colors.grey.shade300
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  canvas.drawLine(Offset(axisW, 0), Offset(axisW, plotH), axisPaint);
  for (final t in domain.ticks) {
    final y = yForValue(t, domain, plotH);
    final tp = TextPainter(text: TextSpan(text: _fmtNum(t), style: _axisStyle), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(axisW - 4 - tp.width, y - tp.height / 2));
  }
}

// ---------------- Scroll layout (React's scroll mode) ----------------
//
// Default layout: fixed 72px slots (default density) widened — up
// to 3x, never past half the visible plot — so category labels
// show in full within 3 lines; the label band is capped at half
// the chart height; the Y axis stays fixed beside a horizontally
// scrolling plot with snap buttons. Painters and hit tests share
// the layout object, so they can never disagree.

double _labelLineHeight() {
  final tp = TextPainter(text: const TextSpan(text: 'Ag', style: _axisStyle), textDirection: TextDirection.ltr)..layout();
  return tp.height;
}

/// One-line label band: line height + padding, at least 30px
/// (React's singleLineHeight).
double _singleLineBand() => math.max(_labelLineHeight() + 13, 30);

/// Whether [label] fits in full at [width] within [maxLines] lines
/// (word-wrapped, no truncation).
bool _labelFits(String label, double width, int maxLines) {
  if (width <= 0) return false;
  final tp = TextPainter(text: TextSpan(text: label, style: _axisStyle), textDirection: TextDirection.ltr, maxLines: maxLines, ellipsis: '…')..layout(maxWidth: width);
  return !tp.didExceedMaxLines;
}

/// Narrowest width in [lo, hi] at which [label] fits within
/// [maxLines] lines, snapped to the widest wrapped line (React's
/// narrowestFullWidth).
double _narrowestFullWidth(String label, double lo, double hi, int maxLines) {
  if (_labelFits(label, lo, maxLines)) return lo;
  while (hi - lo > 0.5) {
    final mid = (lo + hi) / 2;
    if (_labelFits(label, mid, maxLines)) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  final tp = TextPainter(text: TextSpan(text: label, style: _axisStyle), textDirection: TextDirection.ltr, maxLines: maxLines, ellipsis: '…')..layout(maxWidth: hi);
  var w = 0.0;
  for (final line in tp.computeLineMetrics()) {
    w = math.max(w, line.width);
  }
  return w;
}

/// Lines [label] wraps into at [width], capped by [maxLines].
int _labelLines(String label, double width, int maxLines) {
  final tp = TextPainter(text: TextSpan(text: label, style: _axisStyle), textDirection: TextDirection.ltr, maxLines: maxLines, ellipsis: '…')..layout(maxWidth: width);
  return tp.computeLineMetrics().length;
}

/// React's density slot widths, scroll mode only: compact 48,
/// default 72, spacious 96. Anything else falls back to default.
double _densitySlot(String density) {
  switch (density) {
    case 'compact':
      return 48.0;
    case 'spacious':
      return 96.0;
    default:
      return 72.0;
  }
}

/// Resolves the requested X label variant the way React's
/// useChartDimensions does: condensed defaults to singleLine,
/// scroll defaults to multiLine; angled only survives in
/// condensed mode, and narrow containers (< 300px) force
/// singleLine in scroll mode.
String _resolveTickVariant({required bool condensed, String? tickVariant, required double viewportWidth}) {
  if (condensed) return tickVariant ?? 'singleLine';
  if (viewportWidth < 300) return 'singleLine';
  if (tickVariant == 'angled') return 'singleLine';
  return tickVariant ?? 'multiLine';
}

/// Full geometry for a vertical cartesian chart, in content
/// coordinates (the plot painter) plus the fixed axis width.
/// [labelAngle] is 0 for horizontal labels, -pi/4 for condensed
/// angled labels; [labelInterval] thins condensed labels (1 =
/// every label); [labelWidth] is the box a condensed label wraps
/// or truncates to (in scroll mode it is just the slot width).
typedef CartesianLayout = ({YDomain domain, double axisW, double slotWidth, double contentWidth, double labelH, double plotH, int lineCap, bool needsScroll, bool condensed, double labelAngle, int labelInterval, double labelWidth});

CartesianLayout cartesianLayout({required List<String> categories, required List<List<double>> all, required bool stacked, required Size viewport, String density = 'default', bool condensed = false, String? tickVariant}) {
  final variant = _resolveTickVariant(condensed: condensed, tickVariant: tickVariant, viewportWidth: viewport.width);
  if (condensed) {
    return _condensedLayoutPass(categories: categories, all: all, stacked: stacked, viewport: viewport, variant: variant);
  }
  // The buttons take a row below the plot, so a scrolling chart
  // gets a second pass with the reduced height. A smaller height
  // can only widen slots (fewer label lines fit), never un-scroll,
  // so the second pass stays consistent.
  var layout = _cartesianLayoutPass(categories: categories, all: all, stacked: stacked, viewport: viewport, buttonsH: 0, base: _densitySlot(density), variant: variant);
  if (layout.needsScroll) {
    layout = _cartesianLayoutPass(categories: categories, all: all, stacked: stacked, viewport: viewport, buttonsH: 36, base: _densitySlot(density), variant: variant);
  }
  return layout;
}

/// Fit (condensed) geometry: every category shares the container
/// width, nothing scrolls, and labels are thinned, wrapped or
/// rotated per React's condensed layout rules.
CartesianLayout _condensedLayoutPass({required List<String> categories, required List<List<double>> all, required bool stacked, required Size viewport, required String variant}) {
  final n = categories.length;
  final chartH = viewport.height;
  final mm = stacked ? stackedMinMax(all, n) : minMaxOf(all);
  final lineHeight = _labelLineHeight();
  final singleLineH = _singleLineBand();
  final cap = math.max(singleLineH, (chartH * 0.5).floorToDouble());
  final multiLineCap = math.max(1, math.min(3, ((cap - 13) / lineHeight).floor()));
  var domain = niceDomain(mm.min, mm.max, math.max(0.0, chartH - singleLineH));
  var axisW = axisWidthForTicks(domain.ticks);
  var slotWidth = 0.0;
  var labelH = singleLineH;
  var lineCap = 1;
  var labelAngle = 0.0;
  var labelInterval = 1;
  var labelWidth = 0.0;
  // Two fixed-point iterations, as in the scroll pass: the axis
  // width depends on the plot height, the plot height on the
  // label band, and the band on the slot width.
  for (var iter = 0; iter < 2; iter++) {
    axisW = axisWidthForTicks(domain.ticks);
    final availableW = math.max(0.0, viewport.width - axisW);
    slotWidth = n == 0 ? 0.0 : availableW / n;
    var widest = 0.0;
    for (final c in categories) {
      final tp = TextPainter(text: TextSpan(text: c, style: _axisStyle), textDirection: TextDirection.ltr)..layout();
      widest = math.max(widest, tp.width);
    }
    // Angled only when labels actually don't fit horizontally;
    // otherwise an angled request falls back to singleLine, as in
    // React's layout function.
    const sin45 = 0.7071067811865476;
    if (variant == 'angled' && slotWidth > 0 && widest > slotWidth - 8) {
      labelInterval = math.max(1, (lineHeight / sin45 / slotWidth).ceil());
      labelH = math.min(cap, math.max(singleLineH, ((widest + lineHeight) * sin45).ceilToDouble() + 4));
      labelWidth = math.max(0.0, (labelH - 4) / sin45 - lineHeight);
      labelAngle = -math.pi / 4;
      lineCap = 1;
    } else {
      // Thinning: when a category is narrower than 40px + gap,
      // only every n-th label is drawn so each keeps room for a
      // few characters.
      final minWidth = math.min(widest, 40) + 8;
      labelInterval = n == 0 ? 1 : math.min(n, math.max(1, (minWidth / slotWidth).ceil()));
      labelWidth = math.max(0.0, slotWidth * labelInterval - 8);
      labelAngle = 0.0;
      if (variant == 'multiLine') {
        lineCap = multiLineCap;
        var linesUsed = 1;
        for (var i = 0; i < n; i++) {
          if (i % labelInterval != 0) continue;
          linesUsed = math.max(linesUsed, _labelLines(categories[i], labelWidth, lineCap));
        }
        labelH = math.min(math.max(linesUsed * lineHeight + 13, 30), cap);
      } else {
        lineCap = 1;
        labelH = singleLineH;
      }
    }
    domain = niceDomain(mm.min, mm.max, math.max(0.0, chartH - labelH));
  }
  axisW = axisWidthForTicks(domain.ticks);
  final availableW = math.max(0.0, viewport.width - axisW);
  return (domain: domain, axisW: axisW, slotWidth: slotWidth, contentWidth: availableW, labelH: labelH, plotH: math.max(0.0, chartH - labelH), lineCap: lineCap, needsScroll: false, condensed: true, labelAngle: labelAngle, labelInterval: labelInterval, labelWidth: labelWidth);
}

CartesianLayout _cartesianLayoutPass({required List<String> categories, required List<List<double>> all, required bool stacked, required Size viewport, required double buttonsH, required double base, required String variant}) {
  final n = categories.length;
  final chartH = math.max(0.0, viewport.height - buttonsH);
  final mm = stacked ? stackedMinMax(all, n) : minMaxOf(all);
  final lineHeight = _labelLineHeight();
  final singleLineH = _singleLineBand();
  final cap = math.max(singleLineH, (chartH * 0.5).floorToDouble());
  // SingleLine labels never wrap, so the band stays one line and
  // slots widen to the full one-line width instead.
  final lineCap = variant == 'multiLine' ? math.max(1, math.min(3, ((cap - 13) / lineHeight).floor())) : 1;
  // Two fixed-point iterations: the axis width depends on the
  // plot height (tick count), the plot height on the label band,
  // the band on the slot width, and the slot width on the axis
  // width. They converge immediately in practice (the axis only
  // moves when a 40px tick-count boundary is crossed); the layout
  // object is the shared truth either way, so paint and hit test
  // always agree.
  var domain = niceDomain(mm.min, mm.max, math.max(0.0, chartH - singleLineH));
  var axisW = axisWidthForTicks(domain.ticks);
  var slotWidth = base;
  var contentWidth = 0.0;
  var labelH = singleLineH;
  var needsScroll = false;
  for (var iter = 0; iter < 2; iter++) {
    axisW = axisWidthForTicks(domain.ticks);
    final availableW = math.max(0.0, viewport.width - axisW);
    slotWidth = base;
    if (n > 0 && availableW > base) {
      final ceiling = math.max(base, math.min(3 * base, availableW / 2));
      var needed = base;
      for (final label in categories.toSet()) {
        if (_labelFits(label, needed, lineCap) || !_labelFits(label, ceiling, lineCap)) continue;
        final oneLine = (TextPainter(text: TextSpan(text: label, style: _axisStyle), textDirection: TextDirection.ltr)..layout()).width;
        needed = lineCap <= 1 ? oneLine : _narrowestFullWidth(label, needed, math.min(ceiling, oneLine), lineCap);
      }
      if (needed > base) {
        final tight = needed.ceilToDouble();
        final unscrolled = availableW / n;
        final roomy = tight <= unscrolled ? math.min(tight + 8, unscrolled) : tight + 8;
        slotWidth = math.min(ceiling, math.max(base, roomy));
      }
    }
    contentWidth = n == 0 ? availableW : n * slotWidth;
    if (n == 1) contentWidth = math.max(contentWidth, 200);
    needsScroll = contentWidth > availableW;
    if (!needsScroll) {
      slotWidth = n == 0 ? 0 : availableW / n;
      contentWidth = availableW;
    }
    var linesUsed = 1;
    for (final label in categories) {
      linesUsed = math.max(linesUsed, _labelLines(label, slotWidth, lineCap));
    }
    labelH = math.max(linesUsed * lineHeight + 13, 30);
    domain = niceDomain(mm.min, mm.max, math.max(0.0, chartH - labelH));
  }
  axisW = axisWidthForTicks(domain.ticks);
  return (domain: domain, axisW: axisW, slotWidth: slotWidth, contentWidth: contentWidth, labelH: labelH, plotH: math.max(0.0, chartH - labelH), lineCap: lineCap, needsScroll: needsScroll, condensed: false, labelAngle: 0.0, labelInterval: 1, labelWidth: slotWidth);
}

/// Scroll geometry for a horizontal bar chart: rows scroll
/// vertically, the value axis strip stays fixed at the bottom.
typedef HBarLayout = ({YDomain domain, double labelArea, double barX, double barW, double rowH, double contentH, double stripH, bool needsScroll});

HBarLayout hbarLayout({required List<String> categories, required List<List<double>> all, required bool stacked, required Size viewport}) {
  var layout = _hbarLayoutPass(categories: categories, all: all, stacked: stacked, viewport: viewport, buttonsH: 0);
  if (layout.needsScroll) {
    layout = _hbarLayoutPass(categories: categories, all: all, stacked: stacked, viewport: viewport, buttonsH: 36);
  }
  return layout;
}

HBarLayout _hbarLayoutPass({required List<String> categories, required List<List<double>> all, required bool stacked, required Size viewport, required double buttonsH}) {
  final n = categories.length;
  var labelW = 0.0;
  for (final c in categories) {
    final tp = TextPainter(text: TextSpan(text: c, style: _axisStyle), textDirection: TextDirection.ltr)..layout();
    labelW = math.max(labelW, tp.width);
  }
  final labelArea = math.min(labelW, viewport.width * 0.4 - 8);
  final barX = labelArea + 8;
  final barW = math.max(0.0, viewport.width - barX);
  final mm = stacked ? stackedMinMax(all, n) : minMaxOf(all);
  final domain = niceDomain(mm.min, mm.max, barW, pixelsPerTick: 60);
  final stripH = _singleLineBand();
  final scrollH = math.max(0.0, viewport.height - stripH - buttonsH);
  // Rows never shrink below 36px; past that the list scrolls.
  final rowH = n == 0 ? 0.0 : math.max(scrollH / n, 36.0);
  final contentH = n * rowH;
  return (domain: domain, labelArea: labelArea, barX: barX, barW: barW, rowH: rowH, contentH: contentH, stripH: stripH, needsScroll: contentH > scrollH);
}
