part of openui_charts;

// ---------------- Radar ----------------

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.categories, required this.all, required this.palette, required this.maxV, this.hidden = const {}});
  final List<String> categories;
  final List<List<double>> all;
  final List<Color> palette;
  final double maxV;
  final Set<int> hidden;

  @override
  void paint(Canvas canvas, Size size) {
    final n = categories.length;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 24;
    if (n == 0 || radius <= 0) return;
    Offset vertex(int i, double r) {
      final angle = -math.pi / 2 + i * math.pi * 2 / n;
      return center + Offset(math.cos(angle) * r, math.sin(angle) * r);
    }

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (n >= 3) {
      for (final f in [0.25, 0.5, 0.75, 1.0]) {
        final path = Path();
        for (var i = 0; i < n; i++) {
          final p = vertex(i, radius * f);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, gridPaint);
      }
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, vertex(i, radius), gridPaint);
    }
    for (var i = 0; i < n; i++) {
      _paintCenteredText(canvas, categories[i], vertex(i, radius + 14), fontSize: 11);
    }
    // Values scale relative to the largest entry, so the biggest
    // value always reaches the outer ring; all-zero data sits at
    // the center.
    final scale = maxV > 0 ? radius / maxV : 0.0;
    for (var si = 0; si < all.length; si++) {
      if (hidden.contains(si)) continue;
      final vals = all[si];
      double val(int i) => i < vals.length ? vals[i] : 0;
      final color = _colorAt(palette, si);
      if (n == 1) {
        canvas.drawCircle(vertex(0, val(0) * scale), 3, Paint()..color = color);
      } else if (n == 2) {
        // Geometrically degenerate: a line between the two values,
        // not a padded triangle.
        final a = vertex(0, val(0) * scale);
        final b = vertex(1, val(1) * scale);
        canvas.drawLine(a, b, Paint()
          ..color = color
          ..strokeWidth = 2);
        canvas.drawCircle(a, 3, Paint()..color = color);
        canvas.drawCircle(b, 3, Paint()..color = color);
      } else {
        final path = Path();
        for (var i = 0; i < n; i++) {
          final p = vertex(i, val(i) * scale);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.25));
        canvas.drawPath(path, Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

