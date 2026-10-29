part of openui_charts;

// ---------------- Radial (gauge rings) ----------------

class _RadialPainter extends CustomPainter {
  _RadialPainter({required this.values, required this.palette, required this.maxV, this.hidden = const {}, this.hovered});
  final List<double> values;
  final List<Color> palette;
  final double maxV;
  final Set<int> hidden;
  // Legend or ring hover: the hovered ring stays full, the rest
  // dim, like React's stacked-legend linking.
  final int? hovered;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(size.width, size.height) / 2 - 8;
    for (var i = 0; i < values.length; i++) {
      final r = outerR - i * 16;
      if (r <= 5) break;
      // Hidden rings drop out; the rest keep their index-based
      // radii instead of shifting inward.
      if (hidden.contains(i)) continue;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), 0, math.pi * 2, false, Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10);
      final v = i < values.length ? values[i] : 0;
      if (v > 0 && maxV > 0) {
        final color = _colorAt(palette, i);
        canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, v / maxV * math.pi * 2, false, Paint()
          ..color = (hovered != null && hovered != i) ? color.withValues(alpha: 0.4) : color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

