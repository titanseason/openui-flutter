part of openui_charts;

// ---------------- Bar / horizontal bar ----------------

class _BarPainter extends CustomPainter {
  _BarPainter({required this.categories, required this.all, required this.palette, required this.maxY, required this.stacked, required this.horizontal, this.hidden = const {}, this.hoverPos});
  final List<String> categories;
  final List<List<double>> all;
  final List<Color> palette;
  final double maxY;
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
    final plotH = size.height - 22;
    final n = categories.length;
    final slot = size.width / n;
    final m = all.length;
    for (var ci = 0; ci < n; ci++) {
      final x0 = ci * slot;
      // React's hovered-column highlight: a translucent rect over
      // the whole slot, under the bars.
      if (hoverPos != null && _categoryAtX(hoverPos!.dx, size.width, n) == ci) {
        canvas.drawRect(Rect.fromLTWH(x0, 0, slot, plotH), Paint()..color = Colors.grey.withValues(alpha: 0.1));
      }
      if (stacked) {
        final rodW = math.min(16.0, slot);
        final cx = x0 + (slot - rodW) / 2;
        var running = 0.0;
        // Only the topmost segment gets the rounded top.
        var topSi = -1;
        for (var si = 0; si < m; si++) {
          if (!hidden.contains(si) && ci < all[si].length && all[si][ci] > 0) topSi = si;
        }
        for (var si = 0; si < m; si++) {
          if (hidden.contains(si)) continue;
          final v = ci < all[si].length ? all[si][ci] : 0;
          if (v > 0) {
            final top = plotH * (1 - (running + v) / maxY);
            final bottom = plotH * (1 - running / maxY);
            final rect = Rect.fromLTWH(cx, top, rodW, bottom - top);
            final paint = Paint()..color = _colorAt(palette, si);
            if (si == topSi) {
              _drawBarTop(canvas, rect, paint);
            } else {
              canvas.drawRect(rect, paint);
            }
          }
          running += v;
        }
      } else {
        final rodW = m == 0 ? 0.0 : math.min(16.0, slot / m);
        final startX = x0 + (slot - rodW * m) / 2;
        for (var si = 0; si < m; si++) {
          if (hidden.contains(si)) continue;
          final v = ci < all[si].length ? all[si][ci] : 0;
          if (v > 0) {
            final h = plotH * v / maxY;
            _drawBarTop(canvas, Rect.fromLTWH(startX + si * rodW, plotH - h, rodW, h), Paint()..color = _colorAt(palette, si));
          }
        }
      }
      _paintCategoryLabel(canvas, categories[ci], x0 + slot / 2, plotH, slot);
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
    final slot = size.height / n;
    final m = all.length;
    for (var ci = 0; ci < n; ci++) {
      final y0 = ci * slot;
      if (hoverPos != null && _categoryAtY(hoverPos!.dy, size.height, n) == ci) {
        canvas.drawRect(Rect.fromLTWH(0, y0, size.width, slot), Paint()..color = Colors.grey.withValues(alpha: 0.1));
      }
      final tp = TextPainter(text: TextSpan(text: categories[ci], style: _axisStyle), textDirection: TextDirection.ltr, ellipsis: '…')..layout(maxWidth: labelArea);
      tp.paint(canvas, Offset(barX - 8 - tp.width, y0 + (slot - tp.height) / 2));
      if (stacked) {
        final thick = math.min(16.0, slot);
        final cy = y0 + (slot - thick) / 2;
        var running = 0.0;
        // Only the rightmost segment gets the rounded end.
        var endSi = -1;
        for (var si = 0; si < m; si++) {
          if (!hidden.contains(si) && ci < all[si].length && all[si][ci] > 0) endSi = si;
        }
        for (var si = 0; si < m; si++) {
          if (hidden.contains(si)) continue;
          final v = ci < all[si].length ? all[si][ci] : 0;
          if (v > 0) {
            final rect = Rect.fromLTWH(barX + barW * running / maxY, cy, barW * v / maxY, thick);
            final paint = Paint()..color = _colorAt(palette, si);
            if (si == endSi) {
              _drawBarTop(canvas, rect, paint, horizontal: true);
            } else {
              canvas.drawRect(rect, paint);
            }
          }
          running += v;
        }
      } else {
        final thick = m == 0 ? 0.0 : math.min(16.0, slot / m);
        final startY = y0 + (slot - thick * m) / 2;
        for (var si = 0; si < m; si++) {
          if (hidden.contains(si)) continue;
          final v = ci < all[si].length ? all[si][ci] : 0;
          if (v > 0) {
            _drawBarTop(canvas, Rect.fromLTWH(barX, startY + si * thick, barW * v / maxY, thick), Paint()..color = _colorAt(palette, si), horizontal: true);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

