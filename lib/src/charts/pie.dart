part of openui_charts;

// ---------------- Pie ----------------

class _PiePainter extends CustomPainter {
  _PiePainter({required this.labels, required this.values, required this.variant, required this.appearance, required this.palette, this.hidden = const {}});
  final List<String> labels;
  final List<double> values;
  final String variant;
  final String appearance;
  final List<Color> palette;
  final Set<int> hidden;

  @override
  void paint(Canvas canvas, Size size) {
    // Hidden slices drop out and the rest re-normalize over the
    // visible values, like React's legend toggle.
    final visible = <int>[];
    var total = 0.0;
    for (var i = 0; i < labels.length; i++) {
      if (hidden.contains(i)) continue;
      visible.add(i);
      total += i < values.length ? values[i] : 0;
    }
    if (total <= 0 || labels.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(size.width, size.height) / 2 - 4;
    if (outerR <= 0) return;
    final donut = variant == 'donut';
    final semi = appearance == 'semiCircular';
    // Circular starts at 3 o'clock, semi-circular at 9 o'clock so
    // the real sections cover exactly the top half.
    final fullSweep = semi ? math.pi : math.pi * 2;
    var angle = semi ? math.pi : 0.0;
    final gap = 2 / outerR; // ~2px arc gap between sections.
    for (final i in visible) {
      final v = i < values.length ? values[i] : 0;
      final sweep = v / total * fullSweep;
      if (sweep <= 0) continue;
      final inset = math.min(gap / 2, sweep / 2);
      final a0 = angle + inset;
      final a1 = angle + sweep - inset;
      if (a1 > a0) {
        if (donut && outerR > 42) {
          final midR = (outerR + 40) / 2;
          canvas.drawArc(Rect.fromCircle(center: center, radius: midR), a0, a1 - a0, false, Paint()
            ..color = _colorAt(palette, i)
            ..style = PaintingStyle.stroke
            ..strokeWidth = outerR - 40);
        } else {
          final path = Path()
            ..moveTo(center.dx, center.dy)
            ..arcTo(Rect.fromCircle(center: center, radius: outerR), a0, a1 - a0, false)
            ..close();
          canvas.drawPath(path, Paint()..color = _colorAt(palette, i));
        }
      }
      // Section title, white on the slice; skipped for slivers
      // where it could never be readable.
      if (sweep >= 0.25) {
        final mid = angle + sweep / 2;
        final r = donut && outerR > 42 ? (outerR + 40) / 2 : outerR * 0.65;
        _paintCenteredText(canvas, labels[i], center + Offset(math.cos(mid) * r, math.sin(mid) * r), fontSize: 11, color: Colors.white);
      }
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

