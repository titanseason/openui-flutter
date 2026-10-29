part of openui_charts;

const _defaultPalette = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.red];

Color _colorAt(List<Color> palette, int i) => palette.isEmpty ? _defaultPalette[i % _defaultPalette.length] : palette[i % palette.length];

List<double> _seriesValues(ElementNode series) {
  return ((series.props['values'] as List?) ?? const []).map((e) => (e as num?)?.toDouble() ?? 0).toList();
}

const _axisStyle = TextStyle(fontSize: 10, color: Colors.grey);

/// Legend used by the cartesian/radar/scatter widgets: a swatch
/// Container per series (the colour test in controller_theme_test
/// pins this exact shape) plus the series label. With [onToggle]
/// the rows become tappable (React parity: clicking a legend entry
/// hides its series) and hidden rows dim to 0.3. Like React's
/// DefaultLegend, items that don't fit the width collapse behind
/// a "N more" / "Show Less" toggle; when everything fits, the tree
/// is the old one, so the colour test still holds.
class ChartLegend extends StatefulWidget {
  const ChartLegend({required this.labels, required this.palette, this.hidden = const {}, this.onToggle});
  final List<String> labels;
  final List<Color> palette;
  final Set<int> hidden;
  final void Function(int index)? onToggle;
  @override
  State<ChartLegend> createState() => _ChartLegendState();
}

class _ChartLegendState extends State<ChartLegend> {
  bool _expanded = false;

  Widget _row(int i) {
    final row = Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: _colorAt(widget.palette, i)), const SizedBox(width: 4), Text(widget.labels[i])]);
    if (widget.onToggle == null) return row;
    return GestureDetector(
      onTap: () => widget.onToggle!(i),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Opacity(
          opacity: widget.hidden.contains(i) ? 0.3 : 1.0,
          child: row,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        var shown = widget.labels.length;
        var hasMore = false;
        var hiddenCount = 0;
        if (available.isFinite && widget.labels.length > 1) {
          // Greedy fit by measured width, exactly like React's
          // DefaultLegend: item widths plus the 12px gaps.
          final style = DefaultTextStyle.of(context).style;
          double itemW(int i) {
            final tp = TextPainter(text: TextSpan(text: widget.labels[i], style: style), textDirection: TextDirection.ltr)..layout();
            return 10 + 4 + tp.width;
          }

          double buttonW(String text) {
            final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
            return tp.width + 2 + 16;
          }

          int fit(double width) {
            var count = 0;
            var used = 0.0;
            for (var i = 0; i < widget.labels.length; i++) {
              final w = itemW(i) + (count > 0 ? 12 : 0);
              if (used + w <= width) {
                used += w;
                count++;
              } else {
                break;
              }
            }
            return count;
          }

          shown = fit(available);
          if (shown < widget.labels.length) {
            // Reserve the toggle button, then refit (React measures
            // the rendered button; one refit pass is enough here).
            hiddenCount = widget.labels.length - shown;
            shown = fit(available - buttonW('$hiddenCount more') - 12);
            if (shown == 0) shown = 1;
            hiddenCount = widget.labels.length - shown;
            hasMore = true;
          }
        }
        final visible = _expanded ? widget.labels.length : shown;
        return Wrap(
          spacing: 12,
          children: [
            for (var i = 0; i < visible; i++) _row(i),
            if (hasMore)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_expanded ? 'Show Less' : '$hiddenCount more'), const SizedBox(width: 2), Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16)]),
              ),
          ],
        );
      },
    );
  }
}

/// React's stacked legend (the pie/radial default): one 32px row
/// per slice with the label on the left and the share on the right,
/// re-normalized over the visible slices at 1 decimal. Rows hover
/// (highlight in the chart) and tap (toggle); hidden rows dim to
/// 0.3. Past 6 items only the first 6 show until "Show more".
class _StackedLegend extends StatefulWidget {
  const _StackedLegend({required this.labels, required this.values, required this.palette, this.hidden = const {}, required this.onToggle, required this.onHover});
  final List<String> labels;
  final List<double> values;
  final List<Color> palette;
  final Set<int> hidden;
  final void Function(int index) onToggle;
  final void Function(int? index) onHover;
  @override
  State<_StackedLegend> createState() => _StackedLegendState();
}

class _StackedLegendState extends State<_StackedLegend> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visibleTotal = [for (var i = 0; i < widget.values.length; i++) if (!widget.hidden.contains(i)) widget.values[i]].fold<double>(0, (a, b) => a + b);
    final showAll = _expanded || widget.labels.length <= 6;
    final shown = showAll ? widget.labels.length : 6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown; i++)
          GestureDetector(
            onTap: () => widget.onToggle(i),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => widget.onHover(i),
              onExit: (_) => widget.onHover(null),
              child: Opacity(
                opacity: widget.hidden.contains(i) ? 0.3 : 1.0,
                child: SizedBox(
                  height: 32,
                  child: Row(children: [Container(width: 10, height: 10, color: _colorAt(widget.palette, i)), const SizedBox(width: 8), Expanded(child: Text(widget.labels[i])), Text(visibleTotal == 0 ? '0.0%' : '${(widget.values[i] / visibleTotal * 100).toStringAsFixed(1)}%')]),
                ),
              ),
            ),
          ),
        if (widget.labels.length > 6)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_expanded ? 'Show less' : 'Show more'), const SizedBox(width: 2), Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16)]),
          ),
      ],
    );
  }
}

/// Shared legend-toggle state for the chart widgets: tapping a
/// legend entry hides/shows its series (React parity). The
/// painters keep their original indices, so colours never shift
/// when a series is hidden.
mixin _LegendToggle<T extends StatefulWidget> on State<T> {
  final Set<int> hidden = {};
  void toggleLegend(int i) {
    setState(() {
      if (hidden.contains(i)) {
        hidden.remove(i);
      } else {
        hidden.add(i);
      }
    });
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
/// A bar rect with the far end rounded, like the old fl_chart
/// rods: the top for positive vertical bars, the bottom for
/// negative ones ([flip]); the right end for positive horizontal
/// bars, the left end for negative ones. [radius] caps at half
/// the bar thickness.
void _drawBarTop(Canvas canvas, Rect rect, Paint paint, {bool horizontal = false, bool flip = false}) {
  const radius = 6.0;
  final r = horizontal ? math.min(radius, rect.height / 2) : math.min(radius, rect.width / 2);
  final corners = horizontal
      ? (flip ? RRect.fromRectAndCorners(rect, topLeft: Radius.circular(r), bottomLeft: Radius.circular(r)) : RRect.fromRectAndCorners(rect, topRight: Radius.circular(r), bottomRight: Radius.circular(r)))
      : (flip ? RRect.fromRectAndCorners(rect, bottomLeft: Radius.circular(r), bottomRight: Radius.circular(r)) : RRect.fromRectAndCorners(rect, topLeft: Radius.circular(r), topRight: Radius.circular(r)));
  canvas.drawRRect(corners, paint);
}

void _paintCategoryLabel(Canvas canvas, String text, double centerX, double areaTop, double maxWidth) {
  final tp = TextPainter(text: TextSpan(text: text, style: _axisStyle), textDirection: TextDirection.ltr, ellipsis: '…')..layout(maxWidth: maxWidth);
  tp.paint(canvas, Offset(centerX - tp.width / 2, areaTop + (22 - tp.height) / 2));
}

