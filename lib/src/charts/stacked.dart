part of openui_charts;

// ---------------- Single stacked bar ----------------

class _StackedBarPainter extends CustomPainter {
  _StackedBarPainter({required this.values, required this.palette, required this.total});
  final List<double> values;
  final List<Color> palette;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    const colW = 24.0;
    final x = (size.width - colW) / 2;
    var y = size.height;
    var topI = -1;
    for (var i = 0; i < values.length; i++) {
      if (values[i] > 0) topI = i;
    }
    for (var i = 0; i < values.length; i++) {
      final h = size.height * values[i] / total;
      if (h > 0) {
        y -= h;
        final rect = Rect.fromLTWH(x, y, colW, h);
        final paint = Paint()..color = _colorAt(palette, i);
        if (i == topI) {
          _drawBarTop(canvas, rect, paint);
        } else {
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

