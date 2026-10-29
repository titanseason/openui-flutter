part of openui_charts;

// ---------------- Bar / horizontal bar ----------------

class _BarPainter extends CustomPainter {
  _BarPainter({required this.categories, required this.all, required this.palette, required this.stacked, required this.horizontal, this.hidden = const {}, this.hoverPos});
  final List<String> categories;
  final List<List<double>> all;
  final List<Color> palette;
  final bool stacked;
  final bool horizontal;
  final Set<int> hidden;
  final Offset? hoverPos;

  @override
  void paint(Canvas canvas, Size size) {
    if (categories.isEmpty || size.width <= 0 || size.height <= 0) return;
    if (horizontal) {
      _paintHorizontal(canvas, size);
    } else {
      _paintVertical(canvas, size);
    }
  }

  void _paintVertical(Canvas canvas, Size size) {
    final mm = stacked ? stackedMinMax(all, categories.length) : minMaxOf(all);
    final plot = cartesianPlot(dataMin: mm.min, dataMax: mm.max, size: size);
    final domain = plot.domain;
    double y(double v) => yForValue(v, domain, plot.plotH);
    final baseline = y(0);
    _paintAxisTicks(canvas, domain, plot.axisW, plot.plotW, plot.plotH);
    final n = categories.length;
    final slot = plot.plotW / n;
    final m = all.length;
    for (var ci = 0; ci < n; ci++) {
      final x0 = plot.axisW + ci * slot;
      // React's hovered-column highlight: a translucent rect over
      // the whole slot, under the bars.
      if (hoverPos != null && _categoryAtX(hoverPos!.dx, plot.axisW, plot.plotW, n) == ci) {
        canvas.drawRect(Rect.fromLTWH(x0, 0, slot, plot.plotH), Paint()..color = Colors.grey.withValues(alpha: 0.1));
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
      _paintCategoryLabel(canvas, categories[ci], x0 + slot / 2, plot.plotH, slot);
    }
  }

  void _paintHorizontal(Canvas canvas, Size size) {
    final n = categories.length;
    var labelW = 0.0;
    for (final c in categories) {
      final tp = TextPainter(text: TextSpan(text: c, style: _axisStyle), textDirection: TextDirection.ltr)..layout();
      labelW = math.max(labelW, tp.width);
    }
    // Labels stay horizontal and readable; cap their column so a
    // long label cannot eat the whole bar area.
    final labelArea = math.min(labelW, size.width * 0.4 - 8);
    final barX = labelArea + 8;
    final barW = size.width - barX;
    if (barW <= 0) return;
    final plotH = size.height - 22;
    final mm = stacked ? stackedMinMax(all, n) : minMaxOf(all);
    final domain = niceDomain(mm.min, mm.max, barW, pixelsPerTick: 60);
    double x(double v) => barX + barW * (v - domain.min) / (domain.max - domain.min);
    final baseline = x(0);
    _paintValueTicksBottom(canvas, domain, barX, barW, plotH);
    final slot = plotH / n;
    final m = all.length;
    for (var ci = 0; ci < n; ci++) {
      final y0 = ci * slot;
      if (hoverPos != null && _categoryAtY(hoverPos!.dy, plotH, n) == ci) {
        canvas.drawRect(Rect.fromLTWH(0, y0, size.width, slot), Paint()..color = Colors.grey.withValues(alpha: 0.1));
      }
      final tp = TextPainter(text: TextSpan(text: categories[ci], style: _axisStyle), textDirection: TextDirection.ltr, ellipsis: '…')..layout(maxWidth: labelArea);
      tp.paint(canvas, Offset(barX - 8 - tp.width, y0 + (slot - tp.height) / 2));
      if (stacked) {
        final thick = math.min(16.0, slot);
        final cy = y0 + (slot - thick) / 2;
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
        final thick = m == 0 ? 0.0 : math.min(16.0, slot / m);
        final startY = y0 + (slot - thick * m) / 2;
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
