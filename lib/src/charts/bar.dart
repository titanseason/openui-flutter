part of openui_charts;

// ---------------- Bar / horizontal bar ----------------

/// The fixed Y axis column beside a scrolling plot: axis line plus
/// right-aligned tick labels. The gridlines live in the plot
/// painter (they scroll with the content).
class _YAxisPainter extends CustomPainter {
  _YAxisPainter({required this.domain, required this.plotH});
  final YDomain domain;
  final double plotH;
  @override
  void paint(Canvas canvas, Size size) {
    _paintYAxis(canvas, domain, size.width, plotH);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BarPlotPainter extends CustomPainter {
  _BarPlotPainter({required this.categories, required this.all, required this.palette, required this.stacked, required this.layout, this.hidden = const {}, this.hoverPos});
  final List<String> categories;
  final List<List<double>> all;
  final List<Color> palette;
  final bool stacked;
  final CartesianLayout layout;
  final Set<int> hidden;
  final Offset? hoverPos;

  @override
  void paint(Canvas canvas, Size size) {
    if (categories.isEmpty || size.width <= 0 || size.height <= 0) return;
    final domain = layout.domain;
    final plotH = layout.plotH;
    final slot = layout.slotWidth;
    double y(double v) => yForValue(v, domain, plotH);
    final baseline = y(0);
    // Horizontal gridlines across the content width.
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final t in domain.ticks) {
      final gy = y(t);
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gridPaint);
    }
    final n = categories.length;
    final m = all.length;
    for (var ci = 0; ci < n; ci++) {
      final x0 = ci * slot;
      // React's hovered-column highlight: a translucent rect over
      // the whole slot, under the bars.
      final hp = hoverPos;
      if (hp != null && _categoryAtX(hp.dx, 0, layout.contentWidth, n) == ci) {
        canvas.drawRect(Rect.fromLTWH(x0, 0, slot, plotH), Paint()..color = Colors.grey.withValues(alpha: 0.1));
      }
      if (stacked) {
        final rodW = math.min(16.0, slot);
        final cx = x0 + (slot - rodW) / 2;
        var runUp = 0.0;
        var runDown = 0.0;
        // Only the far ends get rounded corners: the topmost
        // positive segment on top, the bottommost negative one at
        // the bottom.
        var topSi = -1;
        var botSi = -1;
        for (var si = 0; si < m; si++) {
          if (hidden.contains(si) || ci >= all[si].length) continue;
          if (all[si][ci] > 0) topSi = si;
          if (all[si][ci] < 0) botSi = si;
        }
        for (var si = 0; si < m; si++) {
          if (hidden.contains(si)) continue;
          final v = ci < all[si].length ? all[si][ci] : 0.0;
          if (v == 0) continue;
          final paint = Paint()..color = _colorAt(palette, si);
          if (v > 0) {
            final rect = Rect.fromLTWH(cx, y(runUp + v), rodW, y(runUp) - y(runUp + v));
            if (si == topSi) {
              _drawBarTop(canvas, rect, paint);
            } else {
              canvas.drawRect(rect, paint);
            }
            runUp += v;
          } else {
            final rect = Rect.fromLTWH(cx, y(runDown), rodW, y(runDown + v) - y(runDown));
            if (si == botSi) {
              _drawBarTop(canvas, rect, paint, flip: true);
            } else {
              canvas.drawRect(rect, paint);
            }
            runDown += v;
          }
        }
      } else {
        final rodW = m == 0 ? 0.0 : math.min(16.0, slot / m);
        final startX = x0 + (slot - rodW * m) / 2;
        for (var si = 0; si < m; si++) {
          if (hidden.contains(si)) continue;
          final v = ci < all[si].length ? all[si][ci] : 0.0;
          if (v == 0) continue;
          final paint = Paint()..color = _colorAt(palette, si);
          if (v > 0) {
            _drawBarTop(canvas, Rect.fromLTWH(startX + si * rodW, y(v), rodW, baseline - y(v)), paint);
          } else {
            _drawBarTop(canvas, Rect.fromLTWH(startX + si * rodW, baseline, rodW, y(v) - baseline), paint, flip: true);
          }
        }
      }
      if (ci % layout.labelInterval == 0) {
        _paintCategoryLabel(canvas, layout, categories[ci], x0 + slot / 2, plotH);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _HBarPlotPainter extends CustomPainter {
  _HBarPlotPainter({required this.categories, required this.all, required this.palette, required this.stacked, required this.layout, this.hidden = const {}, this.hoverPos});
  final List<String> categories;
  final List<List<double>> all;
  final List<Color> palette;
  final bool stacked;
  final HBarLayout layout;
  final Set<int> hidden;
  final Offset? hoverPos;

  @override
  void paint(Canvas canvas, Size size) {
    if (categories.isEmpty || size.width <= 0 || size.height <= 0) return;
    final domain = layout.domain;
    double x(double v) => layout.barX + layout.barW * (v - domain.min) / (domain.max - domain.min);
    final baseline = x(0);
    // Vertical gridlines span the scrolled content height.
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final t in domain.ticks) {
      final gx = x(t);
      canvas.drawLine(Offset(gx, 0), Offset(gx, size.height), gridPaint);
    }
    final n = categories.length;
    final m = all.length;
    for (var ci = 0; ci < n; ci++) {
      final y0 = ci * layout.rowH;
      final hp = hoverPos;
      if (hp != null && _categoryAtY(hp.dy, layout.contentH, n) == ci) {
        canvas.drawRect(Rect.fromLTWH(0, y0, size.width, layout.rowH), Paint()..color = Colors.grey.withValues(alpha: 0.1));
      }
      final tp = TextPainter(text: TextSpan(text: categories[ci], style: _axisStyle), textDirection: TextDirection.ltr, ellipsis: '…')..layout(maxWidth: layout.labelArea);
      tp.paint(canvas, Offset(layout.barX - 8 - tp.width, y0 + (layout.rowH - tp.height) / 2));
      if (stacked) {
        final thick = math.min(16.0, layout.rowH);
        final cy = y0 + (layout.rowH - thick) / 2;
        var runRight = 0.0;
        var runLeft = 0.0;
        var endSi = -1;
        var startSi = -1;
        for (var si = 0; si < m; si++) {
          if (hidden.contains(si) || ci >= all[si].length) continue;
          if (all[si][ci] > 0) endSi = si;
          if (all[si][ci] < 0) startSi = si;
        }
        for (var si = 0; si < m; si++) {
          if (hidden.contains(si)) continue;
          final v = ci < all[si].length ? all[si][ci] : 0.0;
          if (v == 0) continue;
          final paint = Paint()..color = _colorAt(palette, si);
          if (v > 0) {
            final rect = Rect.fromLTWH(x(runRight), cy, x(runRight + v) - x(runRight), thick);
            if (si == endSi) {
              _drawBarTop(canvas, rect, paint, horizontal: true);
            } else {
              canvas.drawRect(rect, paint);
            }
            runRight += v;
          } else {
            final rect = Rect.fromLTWH(x(runLeft + v), cy, x(runLeft) - x(runLeft + v), thick);
            if (si == startSi) {
              _drawBarTop(canvas, rect, paint, horizontal: true, flip: true);
            } else {
              canvas.drawRect(rect, paint);
            }
            runLeft += v;
          }
        }
      } else {
        final thick = m == 0 ? 0.0 : math.min(16.0, layout.rowH / m);
        final startY = y0 + (layout.rowH - thick * m) / 2;
        for (var si = 0; si < m; si++) {
          if (hidden.contains(si)) continue;
          final v = ci < all[si].length ? all[si][ci] : 0.0;
          if (v == 0) continue;
          final paint = Paint()..color = _colorAt(palette, si);
          if (v > 0) {
            _drawBarTop(canvas, Rect.fromLTWH(baseline, startY + si * thick, x(v) - baseline, thick), paint, horizontal: true);
          } else {
            _drawBarTop(canvas, Rect.fromLTWH(x(v), startY + si * thick, baseline - x(v), thick), paint, horizontal: true, flip: true);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// The fixed bottom value-axis strip for horizontal bars: tick
/// labels only (the gridlines scroll with the rows).
class _HBarAxisPainter extends CustomPainter {
  _HBarAxisPainter({required this.layout});
  final HBarLayout layout;
  @override
  void paint(Canvas canvas, Size size) {
    final domain = layout.domain;
    double x(double v) => layout.barX + layout.barW * (v - domain.min) / (domain.max - domain.min);
    for (final t in domain.ticks) {
      _paintWrappedLabel(canvas, _fmtNum(t), x(t), 0, 60, 1);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
