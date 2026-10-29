part of openui_charts;

// ---------------- Single stacked bar ----------------
//
// React's SegmentedBar: one horizontal track, 20px tall, segments
// sized by share of total, 4px padding, 2px gaps, 2px minimum
// segment width, rounded outer corners. Hovering a segment (or a
// legend row) highlights it and dims the rest; there is no legend
// visibility toggle.

class _StackedBarPainter extends CustomPainter {
  _StackedBarPainter({required this.values, required this.palette, required this.total, this.hoveredSegment, this.colors = const ChartColors()});
  final List<double> values;
  final List<Color> palette;
  final double total;
  final int? hoveredSegment;
  final ChartColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    const pad = 4.0, gap = 2.0;
    final track = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6));
    canvas.drawRRect(track, Paint()..color = colors.grid);
    if (total <= 0 || values.isEmpty) return;
    final innerW = size.width - pad * 2 - gap * (values.length - 1);
    var x = pad;
    canvas.save();
    canvas.clipRRect(track);
    for (var i = 0; i < values.length; i++) {
      final w = math.max(2.0, innerW * values[i] / total);
      if (w <= 0) continue;
      final color = _colorAt(palette, i);
      final paint = Paint()..color = (hoveredSegment != null && hoveredSegment != i) ? color.withValues(alpha: 0.4) : color;
      final rect = Rect.fromLTWH(x, pad, w, size.height - pad * 2);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: i == 0 ? const Radius.circular(4) : Radius.zero,
          bottomLeft: i == 0 ? const Radius.circular(4) : Radius.zero,
          topRight: i == values.length - 1 ? const Radius.circular(4) : Radius.zero,
          bottomRight: i == values.length - 1 ? const Radius.circular(4) : Radius.zero,
        ),
        paint,
      );
      // The centered 1px accent line inside each segment.
      if (w > 12) {
        final y = size.height / 2;
        canvas.drawLine(Offset(x + 5, y), Offset(x + w - 5, y), Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..strokeWidth = 1);
      }
      x += w + gap;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
