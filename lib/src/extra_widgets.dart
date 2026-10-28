import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'lang.dart';

/// Icon name to Material icon. Unknown names fall back to a neutral dot
/// icon instead of failing the whole component.
IconData iconByName(String name) {
  switch (name.toLowerCase()) {
    case 'search':
      return Icons.search;
    case 'home':
      return Icons.home;
    case 'settings':
    case 'gear':
      return Icons.settings;
    case 'info':
      return Icons.info;
    case 'warning':
      return Icons.warning;
    case 'error':
      return Icons.error;
    case 'check':
      return Icons.check;
    case 'close':
      return Icons.close;
    case 'add':
    case 'plus':
      return Icons.add;
    case 'edit':
      return Icons.edit;
    case 'delete':
    case 'trash':
      return Icons.delete;
    case 'star':
      return Icons.star;
    case 'heart':
      return Icons.favorite;
    case 'user':
    case 'person':
      return Icons.person;
    case 'calendar':
      return Icons.calendar_today;
    case 'clock':
      return Icons.access_time;
    case 'mail':
    case 'email':
      return Icons.mail;
    case 'phone':
      return Icons.phone;
    case 'link':
      return Icons.link;
    case 'download':
      return Icons.download;
    case 'upload':
      return Icons.upload;
    case 'refresh':
      return Icons.refresh;
    case 'arrow_right':
      return Icons.arrow_forward;
    case 'arrow_left':
      return Icons.arrow_back;
    case 'chevron_right':
      return Icons.chevron_right;
    default:
      return Icons.circle;
  }
}

const _palette = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.red];

List<double> _seriesValues(ElementNode series) {
  return ((series.props['values'] as List?) ?? const []).map((e) => (e as num?)?.toDouble() ?? 0).toList();
}

// ---------------- Radar ----------------

class RadarChartWidget extends StatelessWidget {
  const RadarChartWidget({required this.categories, required this.series});
  final List<String> categories;
  final List<ElementNode> series;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Expanded(child: CustomPaint(painter: _RadarPainter(categories: categories, series: series), size: Size.infinite)),
          Wrap(
            spacing: 12,
            children: [for (var i = 0; i < series.length; i++) Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: _palette[i % _palette.length]), const SizedBox(width: 4), Text(series[i].stringOf('label'))])],
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.categories, required this.series});
  final List<String> categories;
  final List<ElementNode> series;
  @override
  void paint(Canvas canvas, Size size) {
    if (categories.isEmpty || series.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 16;
    var maxV = 1.0;
    final values = [for (final s in series) _seriesValues(s)];
    for (final list in values) {
      for (final v in list) {
        maxV = math.max(maxV, v);
      }
    }
    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < categories.length; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / categories.length;
      final end = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(center, end, axisPaint);
      final tp = TextPainter(text: TextSpan(text: categories[i], style: const TextStyle(fontSize: 10, color: Colors.grey)), textDirection: TextDirection.ltr)..layout();
      final labelPos = center + Offset(math.cos(angle), math.sin(angle)) * (radius + 6);
      tp.paint(canvas, Offset(labelPos.dx - tp.width / 2, labelPos.dy - tp.height / 2));
    }
    for (var si = 0; si < series.length; si++) {
      final path = Path();
      for (var ci = 0; ci < categories.length; ci++) {
        if (ci >= values[si].length) continue;
        final angle = -math.pi / 2 + ci * 2 * math.pi / categories.length;
        final r = values[si][ci] / maxV * radius;
        final p = center + Offset(math.cos(angle), math.sin(angle)) * r;
        if (ci == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = _palette[si % _palette.length].withValues(alpha: 0.25));
      canvas.drawPath(path, Paint()
        ..color = _palette[si % _palette.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.categories != categories || old.series != series;
}

// ---------------- Radial / single stacked ----------------

class RadialChartWidget extends StatelessWidget {
  const RadialChartWidget({required this.slices});
  final List<ElementNode> slices;
  @override
  Widget build(BuildContext context) {
    final maxV = slices.fold<double>(1, (m, s) => math.max(m, s.numOf('value')));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          SizedBox(height: 180, child: CustomPaint(painter: _RadialPainter(slices: slices, maxV: maxV), size: Size.infinite)),
          for (var i = 0; i < slices.length; i++) Row(children: [Container(width: 10, height: 10, color: _palette[i % _palette.length]), const SizedBox(width: 6), Text('${slices[i].stringOf('label')} (${slices[i].numOf('value')})')]),
        ],
      ),
    );
  }
}

class _RadialPainter extends CustomPainter {
  _RadialPainter({required this.slices, required this.maxV});
  final List<ElementNode> slices;
  final double maxV;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = math.min(size.width, size.height) / 2 - 8;
    for (var i = 0; i < slices.length; i++) {
      final radius = outer - i * 14;
      if (radius <= 0) break;
      canvas.drawCircle(center, radius, Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10);
      final sweep = slices[i].numOf('value') / maxV * math.pi * 2;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweep, false, Paint()
        ..color = _palette[i % _palette.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _RadialPainter old) => old.slices != slices || old.maxV != maxV;
}

class SingleStackedBarWidget extends StatelessWidget {
  const SingleStackedBarWidget({required this.slices});
  final List<ElementNode> slices;
  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, n) => s + n.numOf('value'));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < slices.length; i++)
                Expanded(
                  flex: (slices[i].numOf('value') * 100).round().clamp(1, 10000),
                  child: Container(height: 24, color: _palette[i % _palette.length]),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [for (var i = 0; i < slices.length; i++) Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: _palette[i % _palette.length]), const SizedBox(width: 4), Text('${slices[i].stringOf('label')} (${total == 0 ? 0 : (slices[i].numOf('value') / total * 100).round()}%)')])],
          ),
        ],
      ),
    );
  }
}

// ---------------- Scatter ----------------

class ScatterChartWidget extends StatelessWidget {
  const ScatterChartWidget({required this.series});
  final List<ElementNode> series;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Expanded(child: CustomPaint(painter: _ScatterPainter(series: series), size: Size.infinite)),
          Wrap(
            spacing: 12,
            children: [for (var i = 0; i < series.length; i++) Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: _palette[i % _palette.length]), const SizedBox(width: 4), Text(series[i].stringOf('label'))])],
          ),
        ],
      ),
    );
  }
}

class _ScatterPainter extends CustomPainter {
  _ScatterPainter({required this.series});
  final List<ElementNode> series;
  @override
  void paint(Canvas canvas, Size size) {
    var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
    final all = <List<(double, double)>>[];
    for (final s in series) {
      final pts = <(double, double)>[];
      for (final p in s.nodesOf('points')) {
        final x = p.numOf('x');
        final y = p.numOf('y');
        pts.add((x, y));
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
      all.add(pts);
    }
    if (all.isEmpty || minX == double.infinity) return;
    final spanX = (maxX - minX) == 0 ? 1 : maxX - minX;
    final spanY = (maxY - minY) == 0 ? 1 : maxY - minY;
    for (var si = 0; si < all.length; si++) {
      for (final (x, y) in all[si]) {
        final px = 16 + (x - minX) / spanX * (size.width - 32);
        final py = 8 + (size.height - 16) - (y - minY) / spanY * (size.height - 16);
        canvas.drawCircle(Offset(px, py), 5, Paint()..color = _palette[si % _palette.length]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter old) => old.series != series;
}

// ---------------- Option groups ----------------

class MultiSelectGroupWidget extends StatefulWidget {
  const MultiSelectGroupWidget({required this.items, required this.bind, required this.stateValue, required this.onChanged, this.enabled = true});
  final List<ElementNode> items;
  final String? bind;
  final Object? stateValue;
  final void Function(String?, Object?) onChanged;
  final bool enabled;
  @override
  State<MultiSelectGroupWidget> createState() => _MultiSelectGroupWidgetState();
}

class _MultiSelectGroupWidgetState extends State<MultiSelectGroupWidget> {
  final _local = <Object?>{};
  @override
  Widget build(BuildContext context) {
    final selected = widget.stateValue is List ? (widget.stateValue as List).toSet() : _local;
    return Column(
      children: [
        for (final item in widget.items)
          CheckboxListTile(
            title: Text(item.stringOf('label')),
            value: selected.contains(item.props['value'] ?? item.stringOf('label')),
            onChanged: widget.enabled
                ? (v) {
                    final value = item.props['value'] ?? item.stringOf('label');
                    final next = Set.of(selected);
                    if (v == true) {
                      next.add(value);
                    } else {
                      next.remove(value);
                    }
                    if (widget.bind != null) {
                      widget.onChanged(widget.bind, next.toList());
                    } else {
                      setState(() {
                        _local
                          ..clear()
                          ..addAll(next);
                      });
                    }
                  }
                : null,
          ),
      ],
    );
  }
}

class SingleSelectGroupWidget extends StatefulWidget {
  const SingleSelectGroupWidget({required this.items, required this.bind, required this.stateValue, required this.onChanged, this.enabled = true, this.asCards = false});
  final List<ElementNode> items;
  final String? bind;
  final Object? stateValue;
  final void Function(String?, Object?) onChanged;
  final bool enabled;
  final bool asCards;
  @override
  State<SingleSelectGroupWidget> createState() => _SingleSelectGroupWidgetState();
}

class _SingleSelectGroupWidgetState extends State<SingleSelectGroupWidget> {
  Object? _local;
  @override
  Widget build(BuildContext context) {
    final selected = widget.stateValue ?? _local;
    if (widget.asCards) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in widget.items)
            Builder(builder: (context) {
              final value = item.props['value'] ?? item.stringOf('label');
              final isSelected = selected != null && selected == value;
              return Card(
                color: isSelected ? Colors.blue.shade50 : null,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  title: Text(item.stringOf('label')),
                  subtitle: item.props['description'] is String ? Text(item.stringOf('description')) : null,
                  onTap: widget.enabled
                      ? () {
                          if (widget.bind != null) {
                            widget.onChanged(widget.bind, value);
                          } else {
                            setState(() => _local = value);
                          }
                        }
                      : null,
                ),
              );
            }),
        ],
      );
    }
    return RadioGroup<Object?>(
      groupValue: selected,
      onChanged: (v) {
        if (!widget.enabled) return;
        if (widget.bind != null) {
          widget.onChanged(widget.bind, v);
        } else {
          setState(() => _local = v);
        }
      },
      child: Column(
        children: [
          for (final item in widget.items)
            ListTile(
              leading: Radio<Object?>(value: item.props['value'] ?? item.stringOf('label')),
              title: Text(item.stringOf('label')),
              onTap: widget.enabled
                  ? () {
                      final v = item.props['value'] ?? item.stringOf('label');
                      if (widget.bind != null) {
                        widget.onChanged(widget.bind, v);
                      } else {
                        setState(() => _local = v);
                      }
                    }
                  : null,
            ),
        ],
      ),
    );
  }
}

class SwitchGroupWidget extends StatefulWidget {
  const SwitchGroupWidget({required this.items, required this.bind, required this.stateValue, required this.onChanged, this.enabled = true});
  final List<ElementNode> items;
  final String? bind;
  final Object? stateValue;
  final void Function(String?, Object?) onChanged;
  final bool enabled;
  @override
  State<SwitchGroupWidget> createState() => _SwitchGroupWidgetState();
}

class _SwitchGroupWidgetState extends State<SwitchGroupWidget> {
  final _local = <Object?>{};
  @override
  Widget build(BuildContext context) {
    final selected = widget.stateValue is List ? (widget.stateValue as List).toSet() : _local;
    return Column(
      children: [
        for (final item in widget.items)
          SwitchListTile(
            title: Text(item.stringOf('label')),
            value: selected.contains(item.props['value'] ?? item.stringOf('label')),
            onChanged: widget.enabled
                ? (v) {
                    final value = item.props['value'] ?? item.stringOf('label');
                    final next = Set.of(selected);
                    if (v) {
                      next.add(value);
                    } else {
                      next.remove(value);
                    }
                    if (widget.bind != null) {
                      widget.onChanged(widget.bind, next.toList());
                    } else {
                      setState(() {
                        _local
                          ..clear()
                          ..addAll(next);
                      });
                    }
                  }
                : null,
          ),
      ],
    );
  }
}

// ---------------- Date picker / slider fields ----------------

class DatePickerField extends StatelessWidget {
  const DatePickerField({required this.label, required this.bind, required this.value, required this.onChanged, this.enabled = true});
  final String label;
  final String? bind;
  final String? value;
  final void Function(String?, Object?) onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text('$label: ${value ?? '未选择'}')),
          OutlinedButton(
            onPressed: enabled
                ? () async {
                    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) {
                      final iso = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      onChanged(bind, iso);
                    }
                  }
                : null,
            child: const Text('选择日期'),
          ),
        ],
      ),
    );
  }
}

class SliderField extends StatelessWidget {
  const SliderField({required this.label, required this.bind, required this.value, required this.min, required this.max, required this.onChanged, this.enabled = true});
  final String label;
  final String? bind;
  final double value;
  final double min;
  final double max;
  final void Function(String?, Object?) onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.toStringAsFixed(0)}'),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: enabled ? (v) => onChanged(bind, v) : null,
          ),
        ],
      ),
    );
  }
}
