import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'controller.dart';
import 'extra_widgets.dart';
import 'lang.dart';
import 'registry.dart';
import 'theme.dart';

class OpenUIRenderer extends StatefulWidget {
  const OpenUIRenderer({
    super.key,
    required this.library,
    this.response,
    this.isStreaming = false,
    this.onAction,
    this.onStateUpdate,
    this.initialState = const {},
    this.toolProvider,
    this.onToolError,
    this.registry,
    this.controller,
    this.onParseResult,
    this.onError,
  });
  final OpenUILibrary library;
  final String? response;
  final bool isStreaming;
  final void Function(ActionEvent)? onAction;
  final void Function(Map<String, Object?>)? onStateUpdate;
  final Map<String, Object?> initialState;
  final OpenUIToolProvider? toolProvider;
  final void Function(String tool, Object error)? onToolError;
  final ComponentRegistry? registry;

  /// Fired once with a parse's errors when streaming ends (or once
  /// for a non-streaming parse), never per frame during streaming.
  final void Function(List<OpenUIError>)? onParseResult;

  /// Fired at the same point as [onParseResult], once per
  /// non-warning error in that parse.
  final void Function(OpenUIError)? onError;

  /// Controller mode: when supplied, the controller wins over
  /// [response], [onAction], [onStateUpdate], [toolProvider] and
  /// [initialState] — the renderer displays the controller's parsed
  /// result and delegates form changes and actions to it. The old
  /// parameters keep working on their own, unchanged.
  final OpenUIController? controller;

  @override
  State<OpenUIRenderer> createState() => _OpenUIRendererState();
}

class _OpenUIRendererState extends State<OpenUIRenderer> {
  late Map<String, Object?> _state;
  final Map<String, Object?> _queryData = {};
  final Map<String, String> _queryParams = {};
  final Map<String, String> _fetchingParams = {};
  final Map<String, String> _failedParams = {};
  final Map<String, Object> _queryErrors = {};
  final List<QueryRequest> _pendingFetches = [];
  var _fetchScheduled = false;
  var _lastQueries = <QueryRequest>[];
  var _lastMutations = <MutationRequest>[];
  // Parse-callback bookkeeping: callbacks are scheduled post-frame
  // (never fired during build), once per parse result, and never
  // while streaming — only when streaming ends.
  var _seenStreaming = false;
  var _parseCallbackScheduled = false;
  ParseResult? _parseCallbackPending;
  String? _parseCallbackKey;

  void _maybeFireParseCallbacks(ParseResult result, bool streaming) {
    if (widget.onParseResult == null && widget.onError == null) return;
    if (streaming) {
      _seenStreaming = true;
      return;
    }
    final key = '${result.root?.statementId}|${result.root?.component}|${result.errors.map((e) => '${e.code}:${e.message}').join(',')}';
    if (_seenStreaming) {
      // Streaming just ended: fire even if the key matches a
      // previous parse, because this is a new completion.
      _seenStreaming = false;
    } else if (key == _parseCallbackKey) {
      return;
    }
    _parseCallbackKey = key;
    _parseCallbackPending = result;
    if (_parseCallbackScheduled) return;
    _parseCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _parseCallbackScheduled = false;
      final pending = _parseCallbackPending;
      _parseCallbackPending = null;
      if (!mounted || pending == null) return;
      widget.onParseResult?.call(pending.errors);
      for (final e in pending.errors) {
        if (!e.warning) widget.onError?.call(e);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _state = Map.of(widget.initialState);
    widget.controller?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant OpenUIRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  bool get _controllerMode => widget.controller != null;
  bool get _effectiveStreaming => _controllerMode ? widget.controller!.isStreaming : widget.isStreaming;
  OpenUIThemeData get _theme => widget.controller?.effectiveTheme ?? OpenUIThemeData.light();
  ComponentRegistry? get _effectiveRegistry =>
      widget.registry ??
      widget.controller?.registry ??
      // In controller mode the controller's library is the parsed one;
      // fall back to the widget's library otherwise.
      (widget.controller?.library ?? widget.library).registry;

  /// Form-state access that reads the controller in controller mode
  /// and the local map otherwise, so every bound widget (Input,
  /// Select, Chips, groups, DatePicker, Slider) works in both modes
  /// without duplicating its build code.
  Object? _stateValue(String key) => _controllerMode ? widget.controller!.formState[key] : _state[key];
  bool _stateHas(String key) => _controllerMode ? widget.controller!.formState.containsKey(key) : _state.containsKey(key);
  Map<String, Object?> _stateSnapshot() => _controllerMode ? widget.controller!.formState : Map.of(_state);
  void _setValue(String key, Object? value) {
    if (_controllerMode) {
      widget.controller!.setFormValue(key, value);
    } else {
      _updateState(key, value);
    }
  }

  void _updateState(String key, Object? value) {
    setState(() => _state[key] = value);
    widget.onStateUpdate?.call(Map.of(_state));
  }

  String _paramsKey(Map<String, Object?> params) {
    final keys = params.keys.toList()..sort();
    return keys.map((k) => '$k=${params[k]}').join('&');
  }

  void _scheduleFetches(List<QueryRequest> requests) {
    final provider = widget.toolProvider;
    if (provider == null) return;
    var added = false;
    for (final req in requests) {
      final key = _paramsKey(req.params);
      if (_queryData.containsKey(req.statementName) && _queryParams[req.statementName] == key) continue;
      if (_fetchingParams[req.statementName] == key) continue;
      // A failed fetch is not retried on every build; only an explicit
      // @Run refetch (which clears _failedParams) retries it.
      if (_failedParams[req.statementName] == key) continue;
      if (_pendingFetches.any((p) => p.statementName == req.statementName && _paramsKey(p.params) == key)) continue;
      _pendingFetches.add(req);
      added = true;
    }
    if (!added || _fetchScheduled) return;
    _fetchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchScheduled = false;
      final toFetch = List.of(_pendingFetches);
      _pendingFetches.clear();
      for (final req in toFetch) {
        unawaited(_fetchQuery(req));
      }
    });
  }

  Future<void> _fetchQuery(QueryRequest req) async {
    final provider = widget.toolProvider;
    if (provider == null) return;
    final key = _paramsKey(req.params);
    _fetchingParams[req.statementName] = key;
    try {
      final result = await provider(req.tool, req.params);
      if (!mounted) return;
      setState(() {
        _queryData[req.statementName] = result;
        _queryParams[req.statementName] = key;
        _queryErrors.remove(req.statementName);
        _failedParams.remove(req.statementName);
        _fetchingParams.remove(req.statementName);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchingParams.remove(req.statementName);
        _failedParams[req.statementName] = key;
        _queryErrors[req.statementName] = e;
      });
      widget.onToolError?.call(req.tool, e);
    }
  }

  void _refetchAllQueries() {
    final current = List.of(_lastQueries);
    for (final req in current) {
      _queryData.remove(req.statementName);
      _queryParams.remove(req.statementName);
      _failedParams.remove(req.statementName);
      _queryErrors.remove(req.statementName);
    }
    if (mounted) setState(() {});
    _scheduleFetches(current);
  }

  Future<void> _dispatch(Object? action) async {
    if (_controllerMode) {
      await widget.controller!.runAction(action);
      return;
    }
    if (action is List) {
      for (final a in action) {
        final ok = await _dispatchSingle(a);
        if (!ok) break; // a failed mutation stops the rest, per spec
      }
      return;
    }
    await _dispatchSingle(action);
  }

  /// Returns false only when a mutation failed (which stops an action list).
  Future<bool> _dispatchSingle(Object? action) async {
    if (action is! ActionValue) return true;
    switch (action.name) {
      case 'Set':
        if (action.args.isNotEmpty && action.args.first is String) {
          _updateState(action.args.first as String, action.args.length > 1 ? action.args[1] : null);
        }
        widget.onAction?.call(ActionEvent('set', action.args, Map.of(_state)));
        return true;
      case 'Reset':
        setState(() {
          for (final a in action.args) {
            if (a is String) _state.remove(a);
          }
        });
        widget.onStateUpdate?.call(Map.of(_state));
        widget.onAction?.call(ActionEvent('reset', action.args, Map.of(_state)));
        return true;
      case 'Run':
        if (action.args.isEmpty || action.args.first is! String) return true;
        final ref = action.args.first as String;
        MutationRequest? mutation;
        for (final m in _lastMutations) {
          if (m.statementName == ref) mutation = m;
        }
        if (mutation != null) {
          final provider = widget.toolProvider;
          widget.onAction?.call(ActionEvent('run', action.args, Map.of(_state)));
          if (provider == null) return true;
          try {
            final result = await provider(mutation.tool, mutation.params);
            widget.onAction?.call(ActionEvent('mutationResult', [mutation.tool, result], Map.of(_state)));
            _refetchAllQueries();
            return true;
          } catch (e) {
            widget.onToolError?.call(mutation.tool, e);
            widget.onAction?.call(ActionEvent('mutationError', [mutation.tool, '$e'], Map.of(_state)));
            return false;
          }
        }
        QueryRequest? query;
        for (final q in _lastQueries) {
          if (q.statementName == ref) query = q;
        }
        if (query != null) {
          _queryData.remove(query.statementName);
          _queryParams.remove(query.statementName);
          _failedParams.remove(query.statementName);
          _queryErrors.remove(query.statementName);
          _scheduleFetches([query]);
          widget.onAction?.call(ActionEvent('run', action.args, Map.of(_state)));
          return true;
        }
        widget.onAction?.call(ActionEvent('run', action.args, Map.of(_state)));
        return true;
      case 'ToAssistant':
        widget.onAction?.call(ActionEvent('toAssistant', action.args, Map.of(_state)));
        return true;
      case 'OpenUrl':
        widget.onAction?.call(ActionEvent('openUrl', action.args, Map.of(_state)));
        return true;
      default:
        widget.onAction?.call(ActionEvent(action.name, action.args, Map.of(_state)));
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    ParseResult result;
    bool streaming;
    if (_controllerMode) {
      // parseCurrent re-parses with the controller's form state and
      // Query data and schedules fetches; it does not notify, so
      // calling it during build is safe (fetch completion notifies).
      result = widget.controller!.parseCurrent();
      streaming = widget.controller!.isStreaming;
    } else {
      result = parseOpenUI(
        widget.response ?? '',
        widget.library,
        state: _state,
        queryData: _queryData,
        streaming: widget.isStreaming,
        failedQueries: _failedParams.keys.toSet(),
      );
      _lastQueries = result.queries;
      _lastMutations = result.mutations;
      _scheduleFetches(result.queries);
      streaming = widget.isStreaming;
    }
    _maybeFireParseCallbacks(result, streaming);
    final root = result.root;
    if (root == null) {
      if (streaming) return _theme.skeletonBuilder != null ? _theme.skeletonBuilder!(context) : const _Skeleton();
      if (_theme.errorBuilder != null) return _theme.errorBuilder!(context, const OpenUIError('no-root', '暂无可显示的界面'));
      return const Text('暂无可显示的界面');
    }
    // Material ancestor: several components (ListTile, Chip, TextField,
    // CheckboxListTile, SwitchListTile) require one, and a host may place
    // the renderer under MaterialApp without a Scaffold.
    return Material(child: _buildNode(root));
  }

  Widget _buildNode(ElementNode node) {
    // Lookup order: explicit registry first, controller/library
    // registry second (see _effectiveRegistry), built-in switch
    // third, the switch's default last (never a crash).
    final builder = _effectiveRegistry?.lookup(node.component);
    if (builder != null) return builder(context, node, _buildNode);
    switch (node.component) {
      case '__Skeleton':
        return _theme.skeletonBuilder != null ? _theme.skeletonBuilder!(context) : const _Skeleton();
      case '__QueryError':
        // A Query failed and has no data and no initial value. The
        // tool call itself still reports through onToolError (old
        // mode) / the controller's onError stream exactly once per
        // failed fetch; this is only the view.
        final tool = node.stringOf('tool');
        if (_theme.errorBuilder != null) {
          return _theme.errorBuilder!(context, OpenUIError('tool-error', '数据加载失败：$tool'));
        }
        return Text('数据加载失败：$tool');
      case 'Stack':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final c in node.nodesOf('children')) _buildNode(c)],
        );
      case 'Card':
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_theme.cardRadius)),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final c in node.nodesOf('children')) _buildNode(c)],
            ),
          ),
        );
      case 'CardHeader':
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.stringOf('title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (node.props['subtitle'] is String) Text(node.stringOf('subtitle'), style: const TextStyle(color: Colors.grey)),
            ],
          ),
        );
      case 'TextContent':
        final variant = node.stringOf('variant', 'normal');
        final style = switch (variant) {
          'small' => const TextStyle(fontSize: 13, color: Colors.grey),
          'large' => const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          'large-heavy' => const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          _ => const TextStyle(fontSize: 15),
        };
        return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(node.stringOf('text'), style: style));
      case 'MarkdownRenderer':
        return _MarkdownWidget(text: node.stringOf('text'));
      case 'Callout':
        final variant = node.stringOf('variant', 'info');
        final color = switch (variant) {
          'warning' => Colors.orange,
          'error' => Colors.red,
          _ => Colors.blue,
        };
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            border: Border(left: BorderSide(color: color, width: 4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(node.stringOf('text')),
        );
      case 'Image':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              node.stringOf('src'),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 120,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: Text(node.stringOf('alt', '图片加载失败')),
              ),
            ),
          ),
        );
      case 'Table':
        final cols = node.nodesOf('columns');
        if (cols.isEmpty) return const SizedBox.shrink();
        final rows = cols.map((c) => (c.props['values'] as List?) ?? const []).toList();
        final rowCount = rows.fold<int>(0, (m, r) => math.max(m, r.length));
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [for (final c in cols) DataColumn(label: Text(c.stringOf('label')))],
            rows: [
              for (var r = 0; r < rowCount; r++)
                DataRow(cells: [for (var ci = 0; ci < cols.length; ci++) DataCell(Text(ci < rows.length && r < rows[ci].length ? '${rows[ci][r]}' : ''))]),
            ],
          ),
        );
      case 'BarChart':
        return _ChartWidget(kind: _ChartKind.bar, categories: _strings(node.props['categories']), series: node.nodesOf('series'), palette: _theme.chartPalette);
      case 'LineChart':
        return _ChartWidget(kind: _ChartKind.line, categories: _strings(node.props['categories']), series: node.nodesOf('series'), palette: _theme.chartPalette);
      case 'PieChart':
        return _PieWidget(slices: node.nodesOf('slices'), palette: _theme.chartPalette);
      case 'Form':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final c in node.nodesOf('children')) _buildNode(c)],
        );
      case 'Input':
        final bind = node.props['bind'] is String ? node.props['bind'] as String : null;
        final initial = bind != null && _stateHas(bind) ? '${_stateValue(bind)}' : (node.props['value'] == null ? '' : '${node.props['value']}');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextFormField(
            initialValue: initial,
            enabled: !_effectiveStreaming,
            decoration: InputDecoration(
              labelText: node.stringOf('label'),
              hintText: node.props['placeholder'] is String ? node.stringOf('placeholder') : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              if (bind != null) _setValue(bind, v);
            },
          ),
        );
      case 'Select':
        return _SelectWidget(
          options: node.nodesOf('options'),
          bind: node.props['bind'] is String ? node.props['bind'] as String : null,
          stateValue: node.props['bind'] is String ? _stateValue(node.props['bind'] as String) : null,
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      case 'Button':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ElevatedButton(
            onPressed: _effectiveStreaming ? null : () => _dispatch(node.props['action']),
            child: Text(node.stringOf('label')),
          ),
        );
      case 'Chips':
        return _ChipsWidget(
          items: node.nodesOf('items'),
          bind: node.props['bind'] is String ? node.props['bind'] as String : null,
          stateValue: node.props['bind'] is String ? _stateValue(node.props['bind'] as String) : null,
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      case 'FollowUpBlock':
        return Wrap(
          spacing: 8,
          children: [
            for (final item in node.nodesOf('items'))
              OutlinedButton(
                onPressed: () => _controllerMode ? _dispatch(ActionValue('ToAssistant', [item.stringOf('text')])) : widget.onAction?.call(ActionEvent('toAssistant', [item.stringOf('text')], _stateSnapshot())),
                child: Text(item.stringOf('text')),
              ),
          ],
        );
      case 'Tabs':
        return _TabsWidget(items: node.nodesOf('items'), buildNode: _buildNode);
      case 'TabItem':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final c in node.nodesOf('children')) _buildNode(c)],
        );
      // ---- Layout (remaining) ----
      case 'Accordion':
        return Column(children: [for (final c in node.nodesOf('items')) _buildNode(c)]);
      case 'AccordionItem':
        return ExpansionTile(
          title: Text(node.stringOf('label')),
          children: [for (final c in node.nodesOf('children')) _buildNode(c)],
        );
      case 'Steps':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (var i = 0; i < node.nodesOf('items').length; i++) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))), const SizedBox(width: 8), Expanded(child: _buildNode(node.nodesOf('items')[i]))])],
        );
      case 'StepsItem':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(node.stringOf('label'), style: const TextStyle(fontWeight: FontWeight.bold)), for (final c in node.nodesOf('children')) _buildNode(c)],
        );
      case 'Carousel':
        final pages = node.nodesOf('children');
        if (pages.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 220,
          child: PageView(children: [for (final p in pages) SingleChildScrollView(child: _buildNode(p))]),
        );
      case 'Separator':
        return const Divider(height: 24);
      case 'Modal':
        // A real overlay dialog: the node itself renders nothing
        // inline; _ModalWidget shows the dialog once on first build
        // and never re-opens it after close for this render. When
        // the node leaves the tree its state is disposed, so a
        // Modal that re-enters the tree opens again.
        return _ModalWidget(node: node, buildNode: _buildNode);
      case 'SectionBlock':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [if (node.props['title'] is String) Text(node.stringOf('title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), for (final c in node.nodesOf('items')) _buildNode(c)],
        );
      case 'SectionItem':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(node.stringOf('label'), style: const TextStyle(fontWeight: FontWeight.bold)), for (final c in node.nodesOf('children')) _buildNode(c)],
        );
      // ---- Content (remaining) ----
      case 'Text':
        return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(node.stringOf('text')));
      case 'BoldText':
        return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(node.stringOf('text'), style: const TextStyle(fontWeight: FontWeight.bold)));
      case 'TextCallout':
        return _callout(node.stringOf('text'), node.stringOf('variant', 'info'));
      case 'ImageBlock':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(node.stringOf('src'), height: 180, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(height: 120, color: Colors.grey.shade200, alignment: Alignment.center, child: const Text('图片加载失败')))),
            if (node.props['caption'] is String) Padding(padding: const EdgeInsets.only(top: 4), child: Text(node.stringOf('caption'), style: const TextStyle(color: Colors.grey, fontSize: 13))),
          ],
        );
      case 'ImageGallery':
        final images = _strings(node.props['images']);
        return SizedBox(
          height: 140,
          child: ListView(scrollDirection: Axis.horizontal, children: [for (final src in images) Padding(padding: const EdgeInsets.only(right: 8), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(src, width: 200, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 200, color: Colors.grey.shade200))))]),
        );
      case 'ImageText':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(node.stringOf('src'), width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 80, height: 80, color: Colors.grey.shade200))), const SizedBox(width: 8), Expanded(child: Text(node.stringOf('text')))],
        );
      case 'ImageTextLarge':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(node.stringOf('src'), height: 200, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(height: 120, color: Colors.grey.shade200))), const SizedBox(height: 6), Text(node.stringOf('text'))],
        );
      case 'IconText':
        return Row(children: [Icon(iconByName(node.stringOf('icon')), size: 20), const SizedBox(width: 6), Expanded(child: Text(node.stringOf('text')))]);
      case 'CodeBlock':
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(10),
          color: Colors.grey.shade100,
          child: Text(node.stringOf('code'), style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        );
      case 'InlineHeader':
        return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(node.stringOf('text'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
      case 'Icon':
        return Icon(iconByName(node.stringOf('name')));
      // ---- Data (remaining) ----
      case 'EditableTable':
        final cols = node.nodesOf('columns');
        if (cols.isEmpty) return const SizedBox.shrink();
        final rows = cols.map((c) => (c.props['values'] as List?) ?? const []).toList();
        final rowCount = rows.fold<int>(0, (m, r) => math.max(m, r.length));
        // Bound cells (bind == true) read/write form state under
        // "<statementId>:<columnLabel>:<row>"; unbound cells keep
        // the previous local-only behaviour.
        final bound = node.props['bind'] == true;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [for (final c in cols) DataColumn(label: Text(c.stringOf('label')))],
            rows: [
              for (var r = 0; r < rowCount; r++)
                DataRow(cells: [
                  for (var ci = 0; ci < cols.length; ci++)
                    DataCell(SizedBox(
                      width: 120,
                      child: Builder(builder: (context) {
                        final key = '${node.statementId}:${cols[ci].stringOf('label')}:$r';
                        final initial = bound && _stateHas(key)
                            ? '${_stateValue(key)}'
                            : (ci < rows.length && r < rows[ci].length ? '${rows[ci][r]}' : '');
                        return TextFormField(
                          initialValue: initial,
                          decoration: const InputDecoration(border: InputBorder.none),
                          onChanged: bound ? (v) => _setValue(key, v) : null,
                        );
                      }),
                    )),
                ]),
            ],
          ),
        );
      case 'AreaChart':
        return _ChartWidget(kind: _ChartKind.area, categories: _strings(node.props['categories']), series: node.nodesOf('series'), palette: _theme.chartPalette);
      case 'RadarChart':
        return RadarChartWidget(categories: _strings(node.props['categories']), series: node.nodesOf('series'));
      case 'HorizontalBarChart':
        return _ChartWidget(kind: _ChartKind.hbar, categories: _strings(node.props['categories']), series: node.nodesOf('series'), palette: _theme.chartPalette);
      case 'RadialChart':
        return RadialChartWidget(slices: node.nodesOf('slices'));
      case 'SingleStackedBarChart':
        return SingleStackedBarWidget(slices: node.nodesOf('slices'));
      case 'ScatterChart':
        return ScatterChartWidget(series: node.nodesOf('series'));
      case 'TagBlock':
        return Wrap(spacing: 8, children: [for (final c in node.nodesOf('items')) _buildNode(c)]);
      case 'Tag':
        return Chip(label: Text(node.stringOf('label')), avatar: node.props['icon'] is String ? Icon(iconByName(node.stringOf('icon')), size: 18) : null);
      case 'EntityList':
        return Column(children: [for (final item in _strings(node.props['items'])) ListTile(leading: const CircleAvatar(child: Icon(Icons.person, size: 18)), title: Text(item))]);
      case 'MetricIndicatorInline':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [Text('${node.stringOf('label')}: ', style: const TextStyle(color: Colors.grey)), Text('${node.props['value']}', style: const TextStyle(fontWeight: FontWeight.bold)), if (node.props['change'] is String) Padding(padding: const EdgeInsets.only(left: 8), child: Text(node.stringOf('change'), style: TextStyle(color: node.stringOf('change').startsWith('-') ? Colors.red : Colors.green)))]) ,
        );
      case 'MetricIndicatorWithStrikethrough':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [Text('${node.stringOf('label')}: ', style: const TextStyle(color: Colors.grey)), if (node.props['oldValue'] != null) Padding(padding: const EdgeInsets.only(right: 8), child: Text('${node.props['oldValue']}', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey))), Text('${node.props['value']}', style: const TextStyle(fontWeight: FontWeight.bold))]),
        );
      // ---- Form (remaining) ----
      case 'FormControl':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text(node.stringOf('label'), style: const TextStyle(fontWeight: FontWeight.bold)), for (final c in node.nodesOf('children')) _buildNode(c), if (node.props['hint'] is String) Text(node.stringOf('hint'), style: const TextStyle(color: Colors.grey, fontSize: 13))],
          ),
        );
      case 'Label':
        return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(node.stringOf('text'), style: const TextStyle(fontWeight: FontWeight.bold)));
      case 'TextArea':
        final bind = node.props['bind'] is String ? node.props['bind'] as String : null;
        final initial = bind != null && _stateHas(bind) ? '${_stateValue(bind)}' : (node.props['value'] == null ? '' : '${node.props['value']}');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextFormField(
            initialValue: initial,
            maxLines: 4,
            enabled: !_effectiveStreaming,
            decoration: InputDecoration(labelText: node.stringOf('label'), hintText: node.props['placeholder'] is String ? node.stringOf('placeholder') : null, border: const OutlineInputBorder()),
            onChanged: (v) {
              if (bind != null) _setValue(bind, v);
            },
          ),
        );
      case 'DatePicker':
        final bind = node.props['bind'] is String ? node.props['bind'] as String : null;
        final value = bind != null && _stateHas(bind) ? '${_stateValue(bind)}' : (node.props['value'] is String ? node.stringOf('value') : null);
        return DatePickerField(
          label: node.stringOf('label'),
          bind: bind,
          value: value,
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      case 'Slider':
        final bind = node.props['bind'] is String ? node.props['bind'] as String : null;
        final value = bind != null && _stateHas(bind) && _stateValue(bind) is num ? (_stateValue(bind) as num).toDouble() : (node.props['value'] is num ? (node.props['value'] as num).toDouble() : (node.props['min'] is num ? (node.props['min'] as num).toDouble() : 0.0));
        return SliderField(
          label: node.stringOf('label'),
          bind: bind,
          value: value,
          min: node.props['min'] is num ? (node.props['min'] as num).toDouble() : 0,
          max: node.props['max'] is num ? (node.props['max'] as num).toDouble() : 100,
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      case 'CheckBoxGroup':
        return MultiSelectGroupWidget(
          items: node.nodesOf('items'),
          bind: node.props['bind'] is String ? node.props['bind'] as String : null,
          stateValue: node.props['bind'] is String ? _stateValue(node.props['bind'] as String) : null,
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      case 'SwitchGroup':
        return SwitchGroupWidget(
          items: node.nodesOf('items'),
          bind: node.props['bind'] is String ? node.props['bind'] as String : null,
          stateValue: node.props['bind'] is String ? _stateValue(node.props['bind'] as String) : null,
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      case 'RadioGroup':
        return SingleSelectGroupWidget(
          items: node.nodesOf('items'),
          bind: node.props['bind'] is String ? node.props['bind'] as String : null,
          stateValue: node.props['bind'] is String ? _stateValue(node.props['bind'] as String) : null,
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      case 'OptionCards':
        return SingleSelectGroupWidget(
          items: node.nodesOf('items'),
          bind: node.props['bind'] is String ? node.props['bind'] as String : null,
          stateValue: node.props['bind'] is String ? _stateValue(node.props['bind'] as String) : null,
          enabled: !_effectiveStreaming,
          asCards: true,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      // ---- Actions (remaining) ----
      case 'Buttons':
        return Wrap(spacing: 8, children: [for (final c in node.nodesOf('children')) _buildNode(c)]);
      case 'IconButton':
        return IconButton(icon: Icon(iconByName(node.stringOf('icon'))), onPressed: _effectiveStreaming ? null : () => _dispatch(node.props['action']));
      // ---- Dialogue (remaining) ----
      case 'ListBlock':
        return Column(children: [for (final c in node.nodesOf('items')) _buildNode(c)]);
      case 'ListItem':
        return ListTile(leading: const Text('•'), title: Text(node.stringOf('text')));
      // ---- Composite cards ----
      case 'SnippetBlock':
      case 'OverviewBlock':
      case 'ContextBlock':
      case 'CompositeBlock':
      case 'VisualBlock':
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_theme.cardRadius)),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [if (node.props['title'] is String) Text(node.stringOf('title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), for (final c in node.nodesOf('items')) _buildNode(c)],
            ),
          ),
        );
      case 'SnippetItem':
      case 'OverviewItem':
      case 'ContextItem':
      case 'CompositeItem':
      case 'VisualItem':
        return ListTile(
          title: Text(node.stringOf('text')),
          leading: node.props['src'] is String ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(node.stringOf('src'), width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 48, height: 48, color: Colors.grey.shade200))) : null,
          onTap: node.props['action'] != null ? () => _dispatch(node.props['action']) : null,
        );
      default:
        // Col, Series, Slice, ScatterSeries, Point, SelectItem, ChipItem,
        // FollowUpItem, CheckBoxItem, RadioItem, SwitchItem, OptionCard
        // are only meaningful inside their parent; rendered alone they
        // are empty.
        return const SizedBox.shrink();
    }
  }

  Widget _callout(String text, String variant) {
    final color = switch (variant) {
      'warning' => Colors.orange,
      'error' => Colors.red,
      _ => Colors.blue,
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(left: BorderSide(color: color, width: 4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text),
    );
  }

  List<String> _strings(Object? v) {
    if (v is List) return v.map((e) => '$e').toList();
    return const [];
  }
}

/// A Modal node renders nothing inline and shows its content as a
/// real overlay dialog once, on first build. The dialog is shown
/// from a post-frame callback (never during build); the shown and
/// dismissed flags live in this widget's state, so they reset when
/// the Modal node leaves the tree and this state is disposed, or
/// when a different Modal statement takes the same position (see
/// didUpdateWidget), and a closed dialog never re-opens on a later
/// rebuild of the same statement.
class _ModalWidget extends StatefulWidget {
  const _ModalWidget({required this.node, required this.buildNode});
  final ElementNode node;
  final Widget Function(ElementNode) buildNode;
  @override
  State<_ModalWidget> createState() => _ModalWidgetState();
}

class _ModalWidgetState extends State<_ModalWidget> {
  var _dialogShown = false;
  var _dismissed = false;
  var _showScheduled = false;
  var _reopenAfterClose = false;

  @override
  void initState() {
    super.initState();
    _scheduleShow();
  }

  @override
  void didUpdateWidget(covariant _ModalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The brief's guard is keyed by statement, not by widget instance:
    // Flutter reuses this stateful element by position, so a different
    // Modal statement at the same position must not inherit the first
    // statement's dismissed flag. Note: node identity alone is not a
    // key — every re-parse creates new ElementNode objects, so
    // identical() would reset on every rebuild and re-open a closed
    // dialog; statementId is the stable per-statement key.
    if (widget.node.statementId != oldWidget.node.statementId) {
      if (_dialogShown) {
        // The old dialog is still open; do not stack a second one on
        // top. Clear the dismissed flag and re-open once it closes.
        _reopenAfterClose = true;
        _dismissed = false;
      } else {
        _dismissed = false;
        _dialogShown = false;
        _showScheduled = false;
      }
    }
    _scheduleShow();
  }

  void _scheduleShow() {
    if (_dismissed || _dialogShown || _showScheduled) return;
    _showScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showScheduled = false;
      if (!mounted || _dismissed || _dialogShown) return;
      _dialogShown = true;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: widget.node.props['title'] is String ? Text(widget.node.stringOf('title')) : null,
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final c in widget.node.nodesOf('children')) widget.buildNode(c)],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('关闭'))],
        ),
      ).then((_) {
        if (_reopenAfterClose) {
          _reopenAfterClose = false;
          _dialogShown = false;
          _dismissed = false;
          _scheduleShow();
        } else {
          if (mounted) setState(() => _dismissed = true);
          _dialogShown = false;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            height: 16,
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
          ),
      ],
    );
  }
}

// ---------------- Markdown (flutter_markdown_plus) ----------------
// MarkdownRenderer now uses the flutter_markdown_plus package (full
// Markdown: headings, lists, tables, links, code blocks, inline code,
// bold/italic, blockquotes, etc.) instead of the previous hand-written
// subset. MarkdownBody sizes to its content, so it fits inside the
// renderer's Column without its own scroll view.

class _MarkdownWidget extends StatelessWidget {
  const _MarkdownWidget({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return MarkdownBody(data: text);
  }
}

// ---------------- Select / Chips ----------------

class _SelectWidget extends StatelessWidget {
  const _SelectWidget({required this.options, required this.bind, required this.stateValue, required this.onChanged, this.enabled = true});
  final List<ElementNode> options;
  final String? bind;
  final Object? stateValue;
  final bool enabled;
  final void Function(String?, Object?) onChanged;
  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    Object? current = stateValue ?? options.first.props['value'] ?? options.first.stringOf('label');
    final values = options.map((o) => o.props['value'] ?? o.stringOf('label')).toList();
    if (!values.contains(current)) current = values.first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<Object>(
        initialValue: current,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        items: [for (final o in options) DropdownMenuItem(value: o.props['value'] ?? o.stringOf('label'), child: Text(o.stringOf('label')))],
        onChanged: enabled ? (v) => onChanged(bind, v) : null,
      ),
    );
  }
}

class _ChipsWidget extends StatefulWidget {
  const _ChipsWidget({required this.items, required this.bind, required this.stateValue, required this.onChanged, this.enabled = true});
  final List<ElementNode> items;
  final String? bind;
  final Object? stateValue;
  final bool enabled;
  final void Function(String?, Object?) onChanged;
  @override
  State<_ChipsWidget> createState() => _ChipsWidgetState();
}

class _ChipsWidgetState extends State<_ChipsWidget> {
  Object? _local;
  @override
  Widget build(BuildContext context) {
    final selected = widget.stateValue ?? _local;
    return Wrap(
      spacing: 8,
      children: [
        for (final item in widget.items)
          ChoiceChip(
            label: Text(item.stringOf('label')),
            selected: selected != null && selected == (item.props['value'] ?? item.stringOf('label')),
            onSelected: widget.enabled
                ? (v) {
                    if (!v) return;
                    final value = item.props['value'] ?? item.stringOf('label');
                    if (widget.bind != null) {
                      widget.onChanged(widget.bind, value);
                    } else {
                      setState(() => _local = value);
                    }
                  }
                : null,
          ),
      ],
    );
  }
}

// ---------------- Tabs ----------------

class _TabsWidget extends StatefulWidget {
  const _TabsWidget({required this.items, required this.buildNode});
  final List<ElementNode> items;
  final Widget Function(ElementNode) buildNode;
  @override
  State<_TabsWidget> createState() => _TabsWidgetState();
}

class _TabsWidgetState extends State<_TabsWidget> with SingleTickerProviderStateMixin {
  TabController? _controller;
  @override
  void initState() {
    super.initState();
    _controller = TabController(length: widget.items.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _TabsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      final prev = _controller?.index ?? 0;
      _controller?.dispose();
      _controller = TabController(length: widget.items.length, vsync: this, initialIndex: prev < widget.items.length ? prev : 0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final controller = _controller!;
    return Column(
      children: [
        TabBar(
          controller: controller,
          isScrollable: true,
          tabs: [for (final item in widget.items) Tab(text: item.stringOf('label'))],
        ),
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: controller,
            children: [
              for (final item in widget.items)
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final c in item.nodesOf('children')) widget.buildNode(c)],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- Charts (self-drawn, no external deps) ----------------

enum _ChartKind { bar, line, area, hbar }

const _palette = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.red];

class _ChartWidget extends StatelessWidget {
  const _ChartWidget({required this.kind, required this.categories, required this.series, this.palette = _palette});
  final _ChartKind kind;
  final List<String> categories;
  final List<ElementNode> series;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Expanded(child: CustomPaint(painter: _ChartPainter(kind: kind, categories: categories, series: series, palette: palette), size: Size.infinite)),
          Wrap(
            spacing: 12,
            children: [for (var i = 0; i < series.length; i++) Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, color: palette[i % palette.length]), const SizedBox(width: 4), Text(series[i].stringOf('label'))])],
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.kind, required this.categories, required this.series, this.palette = _palette});
  final _ChartKind kind;
  final List<String> categories;
  final List<ElementNode> series;
  final List<Color> palette;
  @override
  void paint(Canvas canvas, Size size) {
    final values = <List<double>>[];
    var maxV = 1.0;
    for (final s in series) {
      final list = ((s.props['values'] as List?) ?? const []).map((e) => (e as num?)?.toDouble() ?? 0).toList();
      values.add(list);
      for (final v in list) {
        maxV = math.max(maxV, v);
      }
    }
    if (categories.isEmpty || values.isEmpty) return;
    final plotW = size.width - 32;
    final plotH = size.height - 24;
    final stepX = plotW / categories.length;
    if (kind == _ChartKind.bar) {
      final groupW = stepX * 0.7;
      final barW = groupW / values.length;
      for (var ci = 0; ci < categories.length; ci++) {
        for (var si = 0; si < values.length; si++) {
          if (ci >= values[si].length) continue;
          final h = values[si][ci] / maxV * plotH;
          final rect = Rect.fromLTWH(16 + ci * stepX + (stepX - groupW) / 2 + si * barW + 1, 8 + plotH - h, barW - 2, h);
          canvas.drawRect(rect, Paint()..color = palette[si % palette.length]);
        }
      }
    } else if (kind == _ChartKind.hbar) {
      final rowH = plotH / categories.length;
      final groupH = rowH * 0.7;
      final barH = groupH / values.length;
      for (var ci = 0; ci < categories.length; ci++) {
        for (var si = 0; si < values.length; si++) {
          if (ci >= values[si].length) continue;
          final w = values[si][ci] / maxV * plotW;
          final rect = Rect.fromLTWH(16, 8 + ci * rowH + (rowH - groupH) / 2 + si * barH + 1, w, barH - 2);
          canvas.drawRect(rect, Paint()..color = palette[si % palette.length]);
        }
      }
    } else {
      for (var si = 0; si < values.length; si++) {
        final paint = Paint()
          ..color = palette[si % palette.length]
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        final path = Path();
        for (var ci = 0; ci < categories.length; ci++) {
          if (ci >= values[si].length) continue;
          final x = 16 + ci * stepX + stepX / 2;
          final y = 8 + plotH - values[si][ci] / maxV * plotH;
          if (ci == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
          canvas.drawCircle(Offset(x, y), 3, Paint()..color = palette[si % palette.length]);
        }
        if (kind == _ChartKind.area && categories.isNotEmpty) {
          final fill = Path.from(path);
          final firstX = 16 + stepX / 2;
          final lastX = 16 + (categories.length - 1) * stepX + stepX / 2;
          fill.lineTo(lastX, 8 + plotH);
          fill.lineTo(firstX, 8 + plotH);
          fill.close();
          canvas.drawPath(fill, Paint()..color = palette[si % palette.length].withValues(alpha: 0.2));
        }
        canvas.drawPath(path, paint);
      }
    }
    final labelStyle = const TextStyle(fontSize: 10, color: Colors.grey);
    for (var ci = 0; ci < categories.length; ci++) {
      final tp = TextPainter(text: TextSpan(text: categories[ci], style: labelStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(16 + ci * stepX + stepX / 2 - tp.width / 2, 8 + plotH + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.kind != kind || old.categories != categories || old.series != series || old.palette != palette;
}

class _PieWidget extends StatelessWidget {
  const _PieWidget({required this.slices, this.palette = _palette});
  final List<ElementNode> slices;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, n) => s + n.numOf('value'));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          SizedBox(height: 180, child: CustomPaint(painter: _PiePainter(slices: slices, total: total == 0 ? 1 : total, palette: palette), size: Size.infinite)),
          for (var i = 0; i < slices.length; i++)
            Row(children: [Container(width: 10, height: 10, color: palette[i % palette.length]), const SizedBox(width: 6), Text('${slices[i].stringOf('label')} (${slices[i].numOf('value')})')]),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.slices, required this.total, this.palette = _palette});
  final List<ElementNode> slices;
  final double total;
  final List<Color> palette;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    var start = -math.pi / 2;
    for (var i = 0; i < slices.length; i++) {
      final sweep = slices[i].numOf('value') / total * math.pi * 2;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, true, Paint()..color = palette[i % palette.length]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => old.slices != slices || old.total != total || old.palette != palette;
}
