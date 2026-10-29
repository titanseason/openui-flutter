part of openui_charts;

// ---------------- Tooltip (React parity: hover tooltip is on by
// default for every chart type) ----------------

/// One tooltip card: a title plus one row per series/slice.
typedef TipRow = ({String label, String value, Color color});
typedef TipData = ({String title, List<TipRow> rows});

/// Plain number formatting, still used for axis tick labels:
/// integers bare, other values to at most 2 decimals trimmed.
String _fmtNum(double v) {
  if (v == v.truncateToDouble()) return v.truncate().toString();
  final s = v.toStringAsFixed(2);
  return s.endsWith('0')
      ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
      : s;
}

/// [_fmtNum] with thousands separators, React's toLocaleString
/// shape (used for scatter coordinates, which React formats
/// without abbreviating).
String _fmtGrouped(double v) {
  final plain = _fmtNum(v);
  final neg = plain.startsWith('-');
  final digits = neg ? plain.substring(1) : plain;
  final dot = digits.indexOf('.');
  final intPart = dot < 0 ? digits : digits.substring(0, dot);
  final fracPart = dot < 0 ? '' : digits.substring(dot);
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return '${neg ? '-' : ''}$buf$fracPart';
}

/// React's shared tooltip number formatter: below 100000 the
/// grouped value, at and above it a K/M/B/T abbreviation floored
/// to 1 decimal (123456 -> 123.4K, 100000 -> 100K).
String _fmtTooltipNum(double v) {
  final abs = v.abs();
  if (abs < 100000) return _fmtGrouped(v);
  const units = ['', 'K', 'M', 'B', 'T'];
  var scaled = abs;
  var unit = 0;
  while (scaled >= 1000 && unit < units.length - 1) {
    scaled /= 1000;
    unit++;
  }
  final floored = (scaled * 10).floor() / 10;
  final num = floored == floored.truncateToDouble()
      ? floored.truncate().toString()
      : floored.toString();
  return '${v < 0 ? '-' : ''}$num${units[unit]}';
}

/// Pure hit functions, kept separate from the widgets so tests can
/// pin them without pumping anything. All return -1 on a miss.

/// Vertical bars / line points by x slot: the slot whose interval
/// contains [dx]. The plot starts at [left] (after the Y axis) and
/// spans [width]; the caller computes both with [cartesianLayout]
/// so the hit test matches the painted grid exactly. Line points
/// sit at slot centers (React's scalePoint), so the hovered point
/// is the hovered slot too.
int _categoryAtX(double dx, double left, double width, int n) {
  if (n <= 0 || width <= 0 || dx < left || dx > left + width) return -1;
  return ((dx - left) / width * n).floor().clamp(0, n - 1);
}

/// Horizontal bars by y slot: rows fill [height] (the bottom value
/// axis strip is not a row).
int _categoryAtY(double dy, double height, int n) {
  if (n <= 0 || height <= 0 || dy < 0 || dy > height) return -1;
  return (dy / height * n).floor().clamp(0, n - 1);
}

/// Pie / donut slice by angle, mirroring [_PiePainter] geometry:
/// circular starts at 3 o'clock, semi-circular at 9 o'clock and
/// covers only the top half.
int _pieSliceAt(Offset pos, Size size, List<double> values) {
  final total = values.fold<double>(0, (a, b) => a + b);
  if (total <= 0 || values.isEmpty) return -1;
  final center = Offset(size.width / 2, size.height / 2);
  final outerR = math.min(size.width, size.height) / 2 - 4;
  if (outerR <= 0) return -1;
  if ((pos - center).distance > outerR) return -1;
  var angle = math.atan2(pos.dy - center.dy, pos.dx - center.dx);
  if (angle < 0) angle += math.pi * 2;
  // The caller passes the already-filtered (visible) values; the
  // painter re-normalizes over exactly those, so shares line up.
  var acc = 0.0;
  for (var i = 0; i < values.length; i++) {
    acc += values[i] / total;
    if (angle < acc * math.pi * 2) return i;
  }
  return values.length - 1;
}

/// Semi-circular pie slice: same geometry, but the bottom half is
/// outside the chart and never hits.
int _semiPieSliceAt(Offset pos, Size size, List<double> values) {
  final total = values.fold<double>(0, (a, b) => a + b);
  if (total <= 0 || values.isEmpty) return -1;
  final center = Offset(size.width / 2, size.height / 2);
  final outerR = math.min(size.width, size.height) / 2 - 4;
  if (outerR <= 0) return -1;
  if ((pos - center).distance > outerR) return -1;
  // Top half only: atan2 in [-pi, 0] maps to [0, pi] from 9 o'clock.
  var angle = math.atan2(pos.dy - center.dy, pos.dx - center.dx);
  if (angle > 0) return -1;
  angle += math.pi;
  var acc = 0.0;
  for (var i = 0; i < values.length; i++) {
    acc += values[i] / total;
    if (angle < acc * math.pi) return i;
  }
  return values.length - 1;
}

/// Radial ring by distance from the center, mirroring
/// [_RadialPainter]: rings at outerR - i*16, 10px thick.
int _radialRingAt(Offset pos, Size size, int count) {
  if (count <= 0) return -1;
  final center = Offset(size.width / 2, size.height / 2);
  final outerR = math.min(size.width, size.height) / 2 - 8;
  final dist = (pos - center).distance;
  for (var i = 0; i < count; i++) {
    final r = outerR - i * 16;
    if (r <= 5) break;
    if ((dist - r).abs() <= 8) return i;
  }
  return -1;
}

/// Radar axis by nearest angle, mirroring [_RadarPainter] vertex
/// angles (-pi/2 + i*2pi/n). No distance gate: near the center the
/// nearest axis still wins, same as hovering a radar vertex.
int _radarAxisAt(Offset pos, Size size, int n) {
  if (n <= 0) return -1;
  final center = Offset(size.width / 2, size.height / 2);
  var angle = math.atan2(pos.dy - center.dy, pos.dx - center.dx);
  // Shift so axis 0 sits at angle 0, then round to nearest.
  angle = (angle + math.pi / 2) % (math.pi * 2);
  return ((angle / (math.pi * 2) * n).round() % n);
}

/// Scatter dot by nearest center within its bubble plus a touch
/// margin; returns the index into [dots]. The mapping mirrors the
/// painter exactly (same [ScatterPlot] from [scatterPlotFor]).
int _scatterDotAt(Offset pos, ScatterPlot plot, List<ScatterDot> dots) {
  if (dots.isEmpty) return -1;
  final spanX = plot.xDomain.max - plot.xDomain.min;
  final spanY = plot.yDomain.max - plot.yDomain.min;
  if (spanX <= 0 || spanY <= 0) return -1;
  var best = -1;
  var bestDist = double.infinity;
  for (var i = 0; i < dots.length; i++) {
    final d = dots[i];
    final px = plot.left + plot.plotW * (d.x - plot.xDomain.min) / spanX;
    final py = plot.plotH - (d.y - plot.yDomain.min) / spanY * plot.plotH;
    final dist = (pos - Offset(px, py)).distance;
    if (dist <= d.radius + 8 && dist < bestDist) {
      best = i;
      bestDist = dist;
    }
  }
  return best;
}

/// Single stacked bar segment by x, left to right, mirroring the
/// painter exactly: 4px padding, 2px gaps, 2px minimum segment
/// width. Hovering a gap returns -1 (no segment).
int _stackedSegmentAtX(
    double dx, double width, List<double> values, double total) {
  if (total <= 0 || values.isEmpty || width <= 0 || dx < 0 || dx > width)
    return -1;
  const pad = 4.0, gap = 2.0;
  final innerW = width - pad * 2 - gap * (values.length - 1);
  var x = pad;
  for (var i = 0; i < values.length; i++) {
    final w = math.max(2.0, innerW * values[i] / total);
    if (dx >= x && dx < x + w) return i;
    x += w + gap;
  }
  return -1;
}

/// The tooltip card itself: white card, bold title, one row per
/// series (swatch + label + value).
class _ChartTip extends StatelessWidget {
  const _ChartTip({required this.tip, this.colors = const ChartColors()});
  final TipData tip;
  // Only the border follows the theme: the card itself stays a
  // light card (its text is uncoloured, so it inherits dark text).
  final ChartColors colors;
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tip.title,
                key: const Key('chart-tip-title'),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            for (var i = 0; i < tip.rows.length; i++)
              Row(
                key: Key('chart-tip-row-$i'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, color: tip.rows[i].color),
                  const SizedBox(width: 6),
                  // The label ellipsizes so a long series name can
                  // never push the row past the card's max width
                  // (the test font renders every glyph a full em
                  // wide, which caught exactly this).
                  Flexible(
                      child: Text(tip.rows[i].label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12))),
                  const SizedBox(width: 12),
                  Text(tip.rows[i].value, style: const TextStyle(fontSize: 12)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a chart's paint area: mouse hover shows the tooltip,
/// touch drag moves it (React's touch semantics: touch-end hides
/// it, a stationary tap shows nothing), and the current hover
/// position reaches the painter so it can draw its highlight
/// (column highlight, active dots). The legend sits outside this
/// area, so legend taps never compete with the pan gesture.
class _HoverArea extends StatefulWidget {
  const _HoverArea({required this.onHover, required this.builder, this.onTap, this.colors = const ChartColors()});
  final ChartColors colors;
  final TipData? Function(Offset pos, Size area) onHover;
  // React's onClick, in Flutter tap shape: a tap (mouse click or
  // stationary touch tap) fires it, a drag does not — the tap and
  // pan recognizers compete, so a drag claims the gesture and no
  // tap fires, matching the tooltip's drag-vs-tap split.
  final void Function(Offset pos, Size area)? onTap;
  // The builder also gets the paint area size, so a painter that
  // needs the area for its own hit math (the stacked track) can
  // derive a hovered index without extra state.
  final Widget Function(BuildContext context, Offset? hoverPos, Size area)
      builder;
  @override
  State<_HoverArea> createState() => _HoverAreaState();
}

class _HoverAreaState extends State<_HoverArea> {
  TipData? _tip;
  Offset? _hoverPos;
  // Manual tap tracking: a TapGestureRecognizer in the same
  // GestureDetector competes with the pan recognizer and starves
  // touch-drag tooltips (verified: the drag test fails with
  // onTapUp present). Raw pointer events sidestep the arena: a
  // down/up pair that never moved past slop is a tap, anything
  // else is a drag and fires no click.
  Offset? _downPos;

  void _update(Offset pos, Size area) {
    setState(() {
      _tip = widget.onHover(pos, area);
      _hoverPos = pos;
    });
  }

  void _clear() {
    if (_tip != null || _hoverPos != null) {
      setState(() {
        _tip = null;
        _hoverPos = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        // Estimated card height (title + rows) for edge flipping;
        // the card itself is capped at 200px wide.
        final estH = 16 + 20 + (_tip?.rows.length ?? 0) * 18;
        final pos = _hoverPos;
        double? left, top;
        if (_tip != null && pos != null) {
          left = (pos.dx + 12 + 200 <= area.width)
              ? pos.dx + 12
              : math.max(0.0, pos.dx - 12 - 200);
          top = (pos.dy + 12 + estH <= area.height)
              ? pos.dy + 12
              : math.max(0.0, pos.dy - 12 - estH);
        }
        return Listener(
          onPointerDown: (e) => _downPos = e.localPosition,
          onPointerUp: (e) {
            final down = _downPos;
            _downPos = null;
            if (down != null &&
                (e.localPosition - down).distance < 18 &&
                widget.onTap != null) {
              widget.onTap!(e.localPosition, area);
            }
          },
          onPointerCancel: (_) => _downPos = null,
          child: GestureDetector(
            onPanUpdate: (d) => _update(d.localPosition, area),
            onPanEnd: (_) => _clear(),
            onPanCancel: _clear,
            child: MouseRegion(
              onEnter: (e) => _update(e.localPosition, area),
              onHover: (e) => _update(e.localPosition, area),
              onExit: (_) => _clear(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.builder(context, _hoverPos, area),
                  if (_tip != null && left != null && top != null)
                    Positioned(
                        left: left, top: top, child: _ChartTip(tip: _tip!, colors: widget.colors)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
