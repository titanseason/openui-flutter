import 'package:flutter/material.dart';

import 'extra_charts.dart';
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

// ---------------- Radar / radial / stacked / scatter (fl_chart) ----------------
// These keep their public names and signatures (a palette parameter was
// added so the theme palette threads through, closing Task 2's deferred
// minor); the implementations live in extra_charts.dart.

class RadarChartWidget extends StatelessWidget {
  const RadarChartWidget({required this.categories, required this.series, this.palette = _palette});
  final List<String> categories;
  final List<ElementNode> series;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) => FlRadarChartWidget(categories: categories, series: series, palette: palette);
}

class RadialChartWidget extends StatelessWidget {
  const RadialChartWidget({required this.slices, this.palette = _palette});
  final List<ElementNode> slices;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) => FlRadialChartWidget(slices: slices, palette: palette);
}

class SingleStackedBarWidget extends StatelessWidget {
  const SingleStackedBarWidget({required this.slices, this.palette = _palette});
  final List<ElementNode> slices;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) => FlStackedBarWidget(slices: slices, palette: palette);
}

class ScatterChartWidget extends StatelessWidget {
  const ScatterChartWidget({required this.series, this.palette = _palette});
  final List<ElementNode> series;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) => FlScatterChartWidget(series: series, palette: palette);
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
