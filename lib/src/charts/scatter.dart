part of openui_charts;

// ---------------- Scatter ----------------

/// One scatter dot in data coordinates, with its bubble radius
/// already resolved.
typedef ScatterDot = ({double x, double y, double radius, int seriesIndex});

/// The scatter layout in data coordinates: dots plus the axis
/// bounds the painter maps from.
typedef ScatterLayout = ({List<ScatterDot> dots, double minX, double maxX, double minY, double maxY});

/// Pure data step of the scatter chart, kept separate from the
/// painter so tests can pin the bubble radii without a widget.
/// A point's z scales its bubble (area proportional to z, as in a
/// bubble chart); points without z keep the default radius.
ScatterLayout computeScatterLayout(List<ElementNode> series) {
  final raw = <({double x, double y, double? z, int si})>[];
  var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity, maxZ = 0.0;
  for (var si = 0; si < series.length; si++) {
    for (final p in series[si].nodesOf('points')) {
      final x = p.numOf('x');
      final y = p.numOf('y');
      final z = p.props['z'] is num ? (p.props['z'] as num).toDouble() : null;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      if (z != null) maxZ = math.max(maxZ, z);
      raw.add((x: x, y: y, z: z, si: si));
    }
  }
  final dots = <ScatterDot>[
    for (final p in raw) (x: p.x, y: p.y, radius: p.z == null ? 6 : (maxZ > 0 ? 4 + 8 * math.sqrt(p.z! / maxZ) : 4), seriesIndex: p.si),
  ];
  if (dots.isEmpty) {
    minX = 0;
    maxX = 1;
    minY = 0;
    maxY = 1;
  }
  return (dots: dots, minX: minX, maxX: maxX == minX ? minX + 1 : maxX, minY: minY, maxY: maxY == minY ? minY + 1 : maxY);
}

class _ScatterPainter extends CustomPainter {
  _ScatterPainter({required this.layout, required this.palette});
  final ScatterLayout layout;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final spanX = layout.maxX - layout.minX;
    final spanY = layout.maxY - layout.minY;
    for (final d in layout.dots) {
      final px = (d.x - layout.minX) / spanX * size.width;
      final py = size.height - (d.y - layout.minY) / spanY * size.height;
      canvas.drawCircle(Offset(px, py), d.radius, Paint()..color = _colorAt(palette, d.seriesIndex));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

