import 'package:flutter/material.dart';

import 'lang.dart';

/// Icon name to Material icon. React names are lucide kebab-case
/// (e.g. 'circle-check'); they are normalized to snake_case for the
/// lookup. When a name does not resolve, React falls back to the
/// category's representative icon (categoryFallbacks), then to a
/// generic dot; this port maps those fallbacks to Material icons
/// instead of failing the whole component.
IconData iconByName(String name, [String? category]) {
  switch (name.toLowerCase().replaceAll('-', '_')) {
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
      return _iconByCategory(category) ?? Icons.circle;
  }
}

/// React's categoryFallbacks (lucide names) mapped to Material icons.
/// Used only when the requested name does not resolve.
IconData? _iconByCategory(String? category) {
  switch (category?.trim().toLowerCase()) {
    case 'accessibility':
      return Icons.accessibility;
    case 'account':
      return Icons.person;
    case 'animals':
      return Icons.pets;
    case 'arrows':
      return Icons.arrow_forward;
    case 'brands':
      return Icons.inventory;
    case 'buildings':
      return Icons.business;
    case 'charts':
      return Icons.show_chart;
    case 'communication':
      return Icons.message;
    case 'connectivity':
      return Icons.wifi;
    case 'cursors':
      return Icons.mouse;
    case 'design':
      return Icons.palette;
    case 'development':
      return Icons.code;
    case 'devices':
      return Icons.smartphone;
    case 'emoji':
      return Icons.emoji_emotions;
    case 'files':
      return Icons.description;
    case 'finance':
      return Icons.attach_money;
    case 'food-beverage':
      return Icons.restaurant;
    case 'gaming':
      return Icons.sports_esports;
    case 'home':
      return Icons.home;
    case 'layout':
      return Icons.dashboard;
    case 'mail':
      return Icons.mail;
    case 'math':
      return Icons.calculate;
    case 'medical':
      return Icons.monitor_heart;
    case 'multimedia':
      return Icons.music_note;
    case 'nature':
      return Icons.park;
    case 'navigation':
      return Icons.location_on;
    case 'notifications':
      return Icons.notifications;
    case 'people':
      return Icons.group;
    case 'photography':
      return Icons.camera_alt;
    case 'science':
      return Icons.science;
    case 'seasons':
      return Icons.wb_sunny;
    case 'security':
      return Icons.shield;
    case 'shapes':
      return Icons.circle;
    case 'shopping':
      return Icons.shopping_cart;
    case 'social':
      return Icons.share;
    case 'sports':
      return Icons.emoji_events;
    case 'sustainability':
      return Icons.eco;
    case 'text':
      return Icons.text_fields;
    case 'time':
      return Icons.access_time;
    case 'tools':
      return Icons.build;
    case 'transportation':
      return Icons.directions_car;
    case 'travel':
      return Icons.flight;
    case 'weather':
      return Icons.cloud;
    default:
      return null;
  }
}

// ---------------- Option groups ----------------

class MultiSelectGroupWidget extends StatefulWidget {
  const MultiSelectGroupWidget({required this.items, required this.stateKey, required this.stateValue, required this.onChanged, this.enabled = true});
  final List<ElementNode> items;
  final String? stateKey;
  // Record of item name to boolean (React's CheckBoxGroup value
  // shape); null means "no state entry yet", and each item then
  // falls back to its defaultChecked prop.
  final Object? stateValue;
  final void Function(String?, Object?) onChanged;
  final bool enabled;
  @override
  State<MultiSelectGroupWidget> createState() => _MultiSelectGroupWidgetState();
}

class _MultiSelectGroupWidgetState extends State<MultiSelectGroupWidget> {
  final _local = <String, bool>{};
  bool _checked(ElementNode item) {
    final name = item.stringOf('name');
    if (widget.stateValue is Map) {
      final record = widget.stateValue as Map;
      if (record.containsKey(name)) return record[name] == true;
    }
    if (widget.stateKey == null && _local.containsKey(name)) return _local[name]!;
    return item.props['defaultChecked'] == true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in widget.items)
          CheckboxListTile(
            title: Text(item.stringOf('label')),
            subtitle: item.props['description'] is String ? Text(item.stringOf('description')) : null,
            value: _checked(item),
            onChanged: widget.enabled
                ? (v) {
                    final next = <String, bool>{};
                    for (final it in widget.items) {
                      next[it.stringOf('name')] = _checked(it);
                    }
                    next[item.stringOf('name')] = v ?? false;
                    if (widget.stateKey != null) {
                      widget.onChanged(widget.stateKey, next);
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
  const SingleSelectGroupWidget({required this.items, required this.stateKey, required this.stateValue, required this.onChanged, this.enabled = true, this.asCards = false, this.multi = false, this.buildNode});
  final List<ElementNode> items;
  final String? stateKey;
  // Single: the selected value string (or the group's defaultValue
  // when no state entry exists yet). Multiple (OptionCards type
  // multiple): a list of selected value strings.
  final Object? stateValue;
  final void Function(String?, Object?) onChanged;
  final bool enabled;
  final bool asCards;
  final bool multi;
  // Renders an OptionCard's topContent node; null renders no top
  // content (RadioGroup items never carry one).
  final Widget Function(ElementNode)? buildNode;
  @override
  State<SingleSelectGroupWidget> createState() => _SingleSelectGroupWidgetState();
}

class _SingleSelectGroupWidgetState extends State<SingleSelectGroupWidget> {
  Object? _local;
  final _localSet = <Object?>{};

  Set<Object?> _selectedSet(Object? selected) {
    if (selected is List) return selected.toSet();
    if (selected is Set) return Set.of(selected);
    if (selected != null) return {selected};
    return const {};
  }

  void _select(Object? value) {
    if (!widget.enabled) return;
    if (widget.stateKey != null) {
      if (widget.multi) {
        final current = widget.stateValue ?? _localSet;
        final next = _selectedSet(current);
        if (next.contains(value)) {
          next.remove(value);
        } else {
          next.add(value);
        }
        widget.onChanged(widget.stateKey, next.toList());
      } else {
        widget.onChanged(widget.stateKey, value);
      }
    } else {
      setState(() {
        if (widget.multi) {
          if (_localSet.contains(value)) {
            _localSet.remove(value);
          } else {
            _localSet.add(value);
          }
        } else {
          _local = value;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.stateValue ?? (widget.multi ? _localSet : _local);
    bool isSelected(Object? value) => widget.multi ? _selectedSet(selected).contains(value) : selected == value;
    if (widget.asCards) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in widget.items)
            Builder(builder: (context) {
              final value = item.props['value'];
              final selectedCard = isSelected(value);
              final disabled = item.props['disabled'] == true;
              final top = item.nodeOf('topContent');
              // OptionCard title/subtitle; a RadioItem never reaches
              // this branch, so the label fallback is defensive only.
              final title = item.props['title'] is String ? item.stringOf('title') : item.stringOf('label');
              final subtitle = item.props['subtitle'] is String ? item.stringOf('subtitle') : (item.props['description'] is String ? item.stringOf('description') : null);
              return Card(
                color: selectedCard ? Colors.blue.shade50 : null,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: selectedCard ? Colors.blue : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (top != null && widget.buildNode != null) widget.buildNode!(top),
                      Text(title),
                    ],
                  ),
                  subtitle: subtitle != null ? Text(subtitle) : null,
                  onTap: (widget.enabled && !disabled) ? () => _select(value) : null,
                ),
              );
            }),
        ],
      );
    }
    // RadioGroup ancestor manages group value (per-Radio groupValue /
    // onChanged are deprecated in this Flutter version). Its onChanged
    // is non-nullable, so the disabled case is handled with
    // IgnorePointer instead of a null callback.
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: RadioGroup<Object?>(
        // This branch is single-select only (multi goes through cards).
        groupValue: selected,
        onChanged: (v) => _select(v),
        child: Column(
          children: [
            for (final item in widget.items)
              ListTile(
                leading: Radio<Object?>(value: item.props['value']),
                title: Text(item.stringOf('label')),
                subtitle: item.props['description'] is String ? Text(item.stringOf('description')) : null,
                onTap: () => _select(item.props['value']),
              ),
          ],
        ),
      ),
    );
  }
}

class SwitchGroupWidget extends StatefulWidget {
  const SwitchGroupWidget({required this.items, required this.stateKey, required this.stateValue, this.variant = 'clear', required this.onChanged, this.enabled = true});
  final List<ElementNode> items;
  final String? stateKey;
  // Record of item name to boolean (React's SwitchGroup value shape);
  // null means "no state entry yet", and each item then falls back
  // to its defaultChecked prop.
  final Object? stateValue;
  // clear | card | sunk. Only card changes the chrome (each tile in
  // a Card); sunk tints the column background.
  final String variant;
  final void Function(String?, Object?) onChanged;
  final bool enabled;
  @override
  State<SwitchGroupWidget> createState() => _SwitchGroupWidgetState();
}

class _SwitchGroupWidgetState extends State<SwitchGroupWidget> {
  final _local = <String, bool>{};
  bool _checked(ElementNode item) {
    final name = item.stringOf('name');
    if (widget.stateValue is Map) {
      final record = widget.stateValue as Map;
      if (record.containsKey(name)) return record[name] == true;
    }
    if (widget.stateKey == null && _local.containsKey(name)) return _local[name]!;
    return item.props['defaultChecked'] == true;
  }

  @override
  Widget build(BuildContext context) {
    Widget tile(ElementNode item) {
      final t = SwitchListTile(
        title: item.props['label'] is String ? Text(item.stringOf('label')) : null,
        subtitle: item.props['description'] is String ? Text(item.stringOf('description')) : null,
        value: _checked(item),
        onChanged: widget.enabled
            ? (v) {
                final next = <String, bool>{};
                for (final it in widget.items) {
                  next[it.stringOf('name')] = _checked(it);
                }
                next[item.stringOf('name')] = v;
                if (widget.stateKey != null) {
                  widget.onChanged(widget.stateKey, next);
                } else {
                  setState(() {
                    _local
                      ..clear()
                      ..addAll(next);
                  });
                }
              }
            : null,
      );
      if (widget.variant == 'card') return Card(child: t);
      return t;
    }

    final column = Column(children: [for (final item in widget.items) tile(item)]);
    if (widget.variant == 'sunk') {
      return Container(color: Colors.grey.shade100, child: column);
    }
    return column;
  }
}

// ---------------- Date picker / slider fields ----------------

class DatePickerField extends StatelessWidget {
  const DatePickerField({required this.stateKey, required this.value, required this.onChanged, this.enabled = true});
  final String? stateKey;
  final String? value;
  final void Function(String?, Object?) onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(value ?? '未选择')),
          OutlinedButton(
            onPressed: enabled
                ? () async {
                    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) {
                      final iso = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      onChanged(stateKey, iso);
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

/// Range-mode date picker: the value is a {from, to} map of
/// yyyy-MM-dd strings, mirroring React's DateRange {from, to} shape.
/// Displays "from → to", either side alone, or 未选择 when empty.
class DateRangeField extends StatelessWidget {
  const DateRangeField({required this.stateKey, required this.value, required this.onChanged, this.enabled = true});
  final String? stateKey;
  final Map? value;
  final void Function(String?, Object?) onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final from = value?['from'] is String ? value!['from'] as String : null;
    final to = value?['to'] is String ? value!['to'] as String : null;
    final display = switch ((from, to)) {
      (String f, String t) => '$f → $t',
      (String f, null) => '$f → ?',
      (null, String t) => '? → $t',
      _ => '未选择',
    };
    String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(display)),
          OutlinedButton(
            onPressed: enabled
                ? () async {
                    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) {
                      onChanged(stateKey, {'from': iso(picked.start), 'to': iso(picked.end)});
                    }
                  }
                : null,
            child: const Text('选择日期范围'),
          ),
        ],
      ),
    );
  }
}

class SliderField extends StatelessWidget {
  const SliderField({required this.label, required this.stateKey, required this.value, required this.min, required this.max, this.divisions, required this.onChanged, this.enabled = true});
  final String? label;
  final String? stateKey;
  final double value;
  final double min;
  final double max;
  // Discrete variant only, from step; null means continuous.
  final int? divisions;
  final void Function(String?, Object?) onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label != null ? '$label: ${value.toStringAsFixed(0)}' : value.toStringAsFixed(0)),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? (v) => onChanged(stateKey, v) : null,
          ),
        ],
      ),
    );
  }
}
