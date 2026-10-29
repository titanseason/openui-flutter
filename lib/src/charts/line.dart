part of openui_charts;

// ---------------- Line / area ----------------

class _LinePainter extends CustomPainter {
  _LinePainter({required this.categories, required this.all, required this.palette, required this.maxY, required this.area, required this.curved, required this.step, this.hidden = const {}, this.hoverPos});
  final List<String> categories;
  final List<List<double>> all;
  final List<Color> palette;
  final double maxY;
  final bool area;
  final bool curved;
  final bool step;
  final Set<int> hidden;
  final Offset? hoverPos;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final plotH = size.height - 22;
    final n = categories.length;
    final denom = math.max(1, n - 1);
    double px(int ci) => size.width * ci / denom;
    double py(double v) => plotH * (1 - v / maxY);
    for (var si = 0; si < all.length; si++) {
      if (hidden.contains(si)) continue;
      final vals = all[si];
      if (vals.isEmpty) continue;
      final pts = [for (var ci = 0; ci < vals.length; ci++) Offset(px(ci), py(vals[ci]))];
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
        final fill = Path.from(path)
          ..lineTo(pts.last.dx, plotH)
          ..lineTo(pts.first.dx, plotH)
          ..close();
        canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.2));
      }
      canvas.drawPath(path, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      for (final p in pts) {
        canvas.drawCircle(p, 4, Paint()..color = color);
      }
      // React's activeDots (default on): the hovered point gets a
      // white ring so it reads as selected. Crosshair lines are
      // opt-in in React, so no vertical line here.
      if (hoverPos != null) {
        final ci = _lineCategoryAtX(hoverPos!.dx, size.width, n);
        if (ci >= 0 && ci < pts.length) {
          canvas.drawCircle(pts[ci], 6, Paint()..color = Colors.white);
          canvas.drawCircle(pts[ci], 4, Paint()..color = color);
        }
      }
    }
    for (var ci = 0; ci < n; ci++) {
      _paintCategoryLabel(canvas, categories[ci], px(ci), plotH, size.width / denom);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

