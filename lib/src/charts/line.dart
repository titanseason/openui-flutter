part of openui_charts;

// ---------------- Line / area ----------------

class _LinePlotPainter extends CustomPainter {
  _LinePlotPainter({required this.categories, required this.all, required this.palette, required this.area, required this.curved, required this.step, required this.layout, this.hidden = const {}, this.hoverPos, this.showDots = false, this.colors = const ChartColors()});
  final List<String> categories;
  final List<List<double>> all;
  final List<Color> palette;
  final bool area;
  final bool curved;
  final bool step;
  final CartesianLayout layout;
  final Set<int> hidden;
  final Offset? hoverPos;
  final ChartColors colors;
  // React's showDots (default false, dotRadius 3): static dots
  // are opt-in; the hovered active dot is separate and always on.
  final bool showDots;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final domain = layout.domain;
    final plotH = layout.plotH;
    final n = categories.length;
    final denom = math.max(1, n - 1);
    double px(int ci) => layout.slotWidth * ci / denom;
    double py(double v) => yForValue(v, domain, plotH);
    // Horizontal gridlines across the content width.
    final gridPaint = Paint()
      ..color = colors.grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final t in domain.ticks) {
      final gy = py(t);
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gridPaint);
    }
    final baseline = py(0);
    for (var si = 0; si < all.length; si++) {
      if (hidden.contains(si)) continue;
      final vals = all[si];
      if (vals.isEmpty) continue;
      // Points span the whole category in scroll mode: the first
      // point sits at the first slot's center, the last at the
      // last slot's center.
      final pts = [for (var ci = 0; ci < vals.length; ci++) Offset(px(ci) + layout.slotWidth / 2, py(vals[ci]))];
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      if (curved && pts.length > 2) {
        // Catmull-Rom to Bezier: a smooth curve through the points,
        // the same shape class as the old curved line chart.
        for (var i = 0; i < pts.length - 1; i++) {
          final p0 = i == 0 ? pts[i] : pts[i - 1];
          final p1 = pts[i];
          final p2 = pts[i + 1];
          final p3 = i + 2 < pts.length ? pts[i + 2] : pts[i + 1];
          path.cubicTo(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6, p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6, p2.dx, p2.dy);
        }
      } else if (step) {
        for (var i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i - 1].dy);
          path.lineTo(pts[i].dx, pts[i].dy);
        }
      } else {
        for (var i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
      }
      final color = _colorAt(palette, si);
      if (area) {
        // Fill down to the zero baseline, not the plot bottom, so
        // negative areas hang below the axis like React's.
        final fill = Path.from(path)
          ..lineTo(pts.last.dx, baseline)
          ..lineTo(pts.first.dx, baseline)
          ..close();
        canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.2));
      }
      canvas.drawPath(path, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      if (showDots) {
        for (final p in pts) {
          canvas.drawCircle(p, 3, Paint()..color = color);
        }
      }
      // React's activeDots (default on): the hovered point gets a
      // white ring so it reads as selected. Crosshair lines are
      // opt-in in React, so no vertical line here.
      final hp = hoverPos;
      if (hp != null) {
        // Points sit at slot centers, so the hovered point is the
        // hovered slot (React's scalePoint).
        final ci = _categoryAtX(hp.dx, 0, layout.contentWidth, n);
        if (ci >= 0 && ci < pts.length) {
          canvas.drawCircle(pts[ci], 6, Paint()..color = Colors.white);
          canvas.drawCircle(pts[ci], 4, Paint()..color = color);
        }
      }
    }
    for (var ci = 0; ci < n; ci++) {
      if (ci % layout.labelInterval != 0) continue;
      _paintCategoryLabel(canvas, layout, categories[ci], ci * layout.slotWidth + layout.slotWidth / 2, plotH, colors: colors);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
