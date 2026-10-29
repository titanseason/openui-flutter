part of openui_charts;

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
/// pins this exact shape) plus the series label. With [onToggle]
/// the rows become tappable (React parity: clicking a legend entry
/// hides its series) and hidden rows dim; without it the tree is
/// exactly the old one, so the colour test still holds.
class ChartLegend extends StatelessWidget {
  const ChartLegend({required this.labels, required this.palette, this.hidden = const {}, this.onToggle});
  final List<String> labels;
  final List<Color> palette;
  final Set<int> hidden;
  final void Function(int index)? onToggle;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        for (var i = 0; i < labels.length; i++)
          if (onToggle == null)
            Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: _colorAt(palette, i)), const SizedBox(width: 4), Text(labels[i])])
          else
            GestureDetector(
              onTap: () => onToggle!(i),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Opacity(
                  opacity: hidden.contains(i) ? 0.4 : 1.0,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: _colorAt(palette, i)), const SizedBox(width: 4), Text(labels[i])]),
                ),
              ),
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

