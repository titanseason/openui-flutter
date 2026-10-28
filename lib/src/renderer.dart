import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'controller.dart';
import 'extra_charts.dart';
import 'extra_widgets.dart';
import 'lang.dart';
import 'primitives.dart';
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

  // Incremental parsing for standalone mode: the State owns one
  // parser per library content, so a growing response is parsed
  // incrementally across builds instead of fully re-parsed on every
  // build. The fingerprint covers names, not function implementations;
  // a host swapping implementations under the same names should
  // rebuild with a new widget key.
  IncrementalOpenUIParser? _incrementalParser;
  String _incrementalFingerprint = '';

  String _libraryFingerprint(OpenUILibrary library) {
    return [library.root, ...library.components.map((c) => c.name), ...library.functions.map((f) => f.name), ...library.actions.map((a) => a.name)].join('|');
  }

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
      final fingerprint = _libraryFingerprint(widget.library);
      if (_incrementalParser == null || fingerprint != _incrementalFingerprint) {
        _incrementalParser = IncrementalOpenUIParser(widget.library);
        _incrementalFingerprint = fingerprint;
      }
      result = _incrementalParser!.parse(
        widget.response ?? '',
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
        return _flexLayout(node, [for (final c in node.nodesOf('children')) _buildNode(c)]);
      case 'Card':
        // The general Card carries variant/flex; the chat Card carries
        // sources. The def decides which props exist; the renderer
        // honors both: sources render as a strip below the card and
        // back inline [n] citations in TextContent descendants.
        final sources = _mapList(node.props['sources']);
        final cardBody = _flexLayout(node, [for (final c in node.nodesOf('children')) _buildNode(sources.isEmpty ? c : _withSources(c, sources))]);
        final card = switch (node.stringOf('variant', 'card')) {
          'clear' => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: cardBody),
          'sunk' => Card(
              color: Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_theme.cardRadius)),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(padding: const EdgeInsets.all(12), child: cardBody),
            ),
          _ => Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_theme.cardRadius)),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(padding: const EdgeInsets.all(12), child: cardBody),
            ),
        };
        if (sources.isEmpty) return card;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            card,
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < sources.length; i++)
                    GestureDetector(
                      onTap: sources[i]['url'] is String && (sources[i]['url'] as String).isNotEmpty && !_effectiveStreaming ? () => _dispatch(ActionValue('OpenUrl', [sources[i]['url'] as String])) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('[${i + 1}] ', style: const TextStyle(color: Colors.grey)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${sources[i]['title'] ?? ''}'),
                                  if (sources[i]['sourceName'] is String) Text(sources[i]['sourceName'] as String, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      case 'CardHeader':
        // Both props are optional now; an empty header renders nothing.
        if (node.props['title'] is! String && node.props['subtitle'] is! String) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (node.props['title'] is String) Text(node.stringOf('title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (node.props['subtitle'] is String) Text(node.stringOf('subtitle'), style: const TextStyle(color: Colors.grey)),
            ],
          ),
        );
      case 'TextContent':
        final size = node.stringOf('size', 'default');
        final style = switch (size) {
          'small' => const TextStyle(fontSize: 13, color: Colors.grey),
          'large' => const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          'small-heavy' => const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          'large-heavy' => const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          _ => const TextStyle(fontSize: 15),
        };
        final textContent = node.stringOf('text');
        final attachedSources = _mapList(node.props['__sources']);
        if (attachedSources.isEmpty) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(textContent, style: style));
        }
        // Inline [n] citations backed by the enclosing chat Card's
        // sources (see _withSources). A marker resolving to a source
        // with a url renders as a tappable link (WidgetSpan, so no
        // gesture-recognizer disposal is involved); out-of-range
        // markers and url-less sources render as plain text.
        final spans = <InlineSpan>[];
        final citationPattern = RegExp(r'\[(\d+)\]');
        var last = 0;
        for (final m in citationPattern.allMatches(textContent)) {
          if (m.start > last) spans.add(TextSpan(text: textContent.substring(last, m.start)));
          final n = int.tryParse(m.group(1)!);
          final marker = m.group(0)!;
          if (n != null && n >= 1 && n <= attachedSources.length) {
            final url = attachedSources[n - 1]['url'];
            if (url is String && url.isNotEmpty) {
              spans.add(WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: _effectiveStreaming ? null : () => _dispatch(ActionValue('OpenUrl', [url])),
                  child: Text(marker, style: style.copyWith(color: Colors.blue, decoration: TextDecoration.underline)),
                ),
              ));
            } else {
              spans.add(TextSpan(text: marker));
            }
          } else {
            spans.add(TextSpan(text: marker));
          }
          last = m.end;
        }
        if (last < textContent.length) spans.add(TextSpan(text: textContent.substring(last)));
        return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text.rich(TextSpan(style: style, children: spans)));
      case 'MarkDownRenderer':
        final body = _MarkdownWidget(text: node.stringOf('textMarkdown'));
        return switch (node.stringOf('variant', 'clear')) {
          'card' => Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_theme.cardRadius)),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(padding: const EdgeInsets.all(12), child: body),
            ),
          'sunk' => Container(margin: const EdgeInsets.symmetric(vertical: 6), padding: const EdgeInsets.all(12), color: Colors.grey.shade100, child: body),
          _ => body,
        };
      case 'Callout':
        // visible == false renders nothing; absent means visible.
        if (node.props['visible'] == false) return const SizedBox.shrink();
        final calloutColor = switch (node.stringOf('variant')) {
          'warning' => Colors.orange,
          'error' => Colors.red,
          'success' => Colors.green,
          'neutral' => Colors.grey,
          _ => Colors.blue,
        };
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: calloutColor.withValues(alpha: 0.08),
            border: Border(left: BorderSide(color: calloutColor, width: 4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.stringOf('title'), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(node.stringOf('description')),
            ],
          ),
        );
      case 'Image':
        final src = node.props['src'] is String ? node.stringOf('src') : null;
        // src is optional now; without it the required alt text is shown.
        if (src == null) return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(node.stringOf('alt')));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              src,
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
        // A failed Query inside the columns used to degrade to an
        // empty column (an __QueryError node has no label/values).
        // Surface the error instead, consistently with the
        // __QueryError view for direct dependents: the theme error
        // builder when supplied, else the same failure text.
        ElementNode? failedCol;
        for (final c in cols) {
          if (c.component == '__QueryError') {
            failedCol = c;
            break;
          }
        }
        if (failedCol != null) {
          final tool = failedCol.stringOf('tool');
          if (_theme.errorBuilder != null) {
            return _theme.errorBuilder!(context, OpenUIError('tool-error', '数据加载失败：$tool'));
          }
          return Text('数据加载失败：$tool');
        }
        // A loading Query inside the columns becomes a __Skeleton
        // placeholder node; render a table-shaped skeleton instead
        // of an empty DataTable. (A Col with genuinely empty values
        // is not a skeleton and still renders a normal table.)
        if (cols.any((c) => c.component == '__Skeleton')) return const TableSkeleton();
        final rows = cols.map((c) => (c.props['data'] as List?) ?? const []).toList();
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
        return _ChartWidget(kind: _ChartKind.bar, categories: _strings(node.props['labels']), series: node.nodesOf('series'), palette: _theme.chartPalette, stacked: node.stringOf('variant') == 'stacked', xLabel: node.props['xLabel'] is String ? node.stringOf('xLabel') : null, yLabel: node.props['yLabel'] is String ? node.stringOf('yLabel') : null, height: node.props['height'] is num ? (node.props['height'] as num).toDouble() : null);
      case 'LineChart':
        return _ChartWidget(kind: _ChartKind.line, categories: _strings(node.props['labels']), series: node.nodesOf('series'), palette: _theme.chartPalette, curve: node.stringOf('variant'), xLabel: node.props['xLabel'] is String ? node.stringOf('xLabel') : null, yLabel: node.props['yLabel'] is String ? node.stringOf('yLabel') : null, height: node.props['height'] is num ? (node.props['height'] as num).toDouble() : null);
      case 'PieChart':
        return _PieWidget(labels: _strings(node.props['labels']), values: _numbers(node.props['values']), variant: node.stringOf('variant', 'pie'), appearance: node.stringOf('appearance', 'circular'), palette: _theme.chartPalette);
      case 'Form':
        // Fields render in order, then the Buttons node. `name` is the
        // form identifier and renders nothing by itself.
        final formButtons = node.nodeOf('buttons');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final c in node.nodesOf('fields')) _buildNode(c), if (formButtons != null) _buildNode(formButtons)],
        );
      case 'Input':
        // State key is `name`; the old `label`/`bind` props are gone
        // (the label belongs on FormControl now).
        final inputKey = node.stringOf('name');
        final initial = _stateHas(inputKey) ? '${_stateValue(inputKey)}' : (node.props['value'] == null ? '' : '${node.props['value']}');
        final inputType = node.stringOf('type', 'text');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextFormField(
            initialValue: initial,
            enabled: !_effectiveStreaming,
            obscureText: inputType == 'password',
            keyboardType: switch (inputType) {
              'email' => TextInputType.emailAddress,
              'number' => TextInputType.number,
              'url' => TextInputType.url,
              _ => TextInputType.text,
            },
            decoration: InputDecoration(
              hintText: node.props['placeholder'] is String ? node.stringOf('placeholder') : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => _setValue(inputKey, v),
          ),
        );
      case 'Select':
        final selectKey = node.stringOf('name');
        return _SelectWidget(
          items: node.nodesOf('items'),
          stateKey: selectKey,
          stateValue: _stateHas(selectKey) ? _stateValue(selectKey) : node.props['value'],
          placeholder: node.props['placeholder'] is String ? node.stringOf('placeholder') : null,
          size: node.stringOf('size', 'medium'),
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      case 'Button':
        final destructive = node.stringOf('type', 'normal') == 'destructive';
        final buttonFontSize = switch (node.stringOf('size', 'medium')) {
          'extra-small' => 12.0,
          'small' => 13.0,
          'large' => 17.0,
          _ => 15.0,
        };
        final buttonPadding = switch (node.stringOf('size', 'medium')) {
          'extra-small' => const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          'small' => const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          'large' => const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          _ => const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        };
        final buttonLabel = Text(node.stringOf('label'), style: TextStyle(fontSize: buttonFontSize));
        final onPressed = _effectiveStreaming ? null : () => _dispatch(node.props['action']);
        final button = switch (node.stringOf('variant', 'primary')) {
          'secondary' => OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(padding: buttonPadding, foregroundColor: destructive ? Colors.red : null, side: destructive ? const BorderSide(color: Colors.red) : null),
              child: buttonLabel,
            ),
          'tertiary' => TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(padding: buttonPadding, foregroundColor: destructive ? Colors.red : null),
              child: buttonLabel,
            ),
          _ => ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(padding: buttonPadding, foregroundColor: destructive ? Colors.white : null, backgroundColor: destructive ? Colors.red : null),
              child: buttonLabel,
            ),
        };
        return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: button);
      case 'Chips':
        final chipsKey = node.stringOf('name');
        return _ChipsWidget(
          items: node.nodesOf('items'),
          stateKey: chipsKey,
          stateValue: _stateHas(chipsKey) ? _stateValue(chipsKey) : node.props['defaultValue'],
          type: node.stringOf('type', 'multiple'),
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
          children: [for (final c in node.nodesOf('content')) _buildNode(c)],
        );
      // ---- Layout (remaining) ----
      case 'Accordion':
        return Column(children: [for (final c in node.nodesOf('items')) _buildNode(c)]);
      case 'AccordionItem':
        return ExpansionTile(
          title: Text(node.stringOf('trigger')),
          children: [for (final c in node.nodesOf('content')) _buildNode(c)],
        );
      case 'Steps':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (var i = 0; i < node.nodesOf('items').length; i++) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))), const SizedBox(width: 8), Expanded(child: _buildNode(node.nodesOf('items')[i]))])],
        );
      case 'StepsItem':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(node.stringOf('title'), style: const TextStyle(fontWeight: FontWeight.bold)), Text(node.stringOf('details'))],
        );
      case 'Carousel':
        // children is a list of slides; each slide is a list of nodes
        // (a bare node is leniently treated as a one-node slide).
        final slides = <List<ElementNode>>[];
        if (node.props['children'] is List) {
          for (final slide in (node.props['children'] as List)) {
            if (slide is List) {
              slides.add([for (final n in slide) if (n is ElementNode) n]);
            } else if (slide is ElementNode) {
              slides.add([slide]);
            }
          }
        }
        if (slides.isEmpty) return const SizedBox.shrink();
        final sunk = node.stringOf('variant', 'card') == 'sunk';
        return SizedBox(
          height: 220,
          child: PageView(
            children: [
              for (final slide in slides)
                Container(
                  color: sunk ? Colors.grey.shade100 : null,
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final c in slide) _buildNode(c)]),
                  ),
                ),
            ],
          ),
        );
      case 'Separator':
        // decorative separators are hidden from assistive tech, as
        // React's aria-hidden decorative separators.
        final Widget divider = node.stringOf('orientation', 'horizontal') == 'vertical'
            ? Center(child: Container(width: 1, height: 24, color: Colors.grey.shade300))
            : const Divider(height: 24);
        if (node.props['decorative'] == true) return ExcludeSemantics(child: divider);
        return divider;
      case 'Modal':
        // A real overlay dialog: the node itself renders nothing
        // inline; _ModalWidget shows the dialog once on first build
        // and never re-opens it after close for this render. When
        // the node leaves the tree its state is disposed, so a
        // Modal that re-enters the tree opens again. open == false
        // renders nothing and never opens the dialog.
        return _ModalWidget(node: node, buildNode: _buildNode, open: node.props['open'] != false, size: node.stringOf('size', 'md'));
      case 'SectionBlock':
        final sections = node.nodesOf('sections');
        if (node.props['isFoldable'] == true) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final s in sections) ExpansionTile(title: Text(s.stringOf('trigger')), children: [for (final c in s.nodesOf('content')) _buildNode(c)])],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final s in sections) _buildNode(s)],
        );
      case 'SectionItem':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(node.stringOf('trigger'), style: const TextStyle(fontWeight: FontWeight.bold)), for (final c in node.nodesOf('content')) _buildNode(c)],
        );
      // ---- Content (remaining) ----
      case 'Text':
      case 'BoldText':
        // value-first is a documented deviation from schema order
        // (see library.dart). variant number vs text is semantic
        // only in this port: no distinct styling. subtextVariant is
        // accepted but likewise has no distinct styling.
        final textBold = node.component == 'BoldText';
        final textSize = switch (node.stringOf('size', 'sm')) {
          'xs' => 11.0,
          'md' => 15.0,
          'lg' => 18.0,
          _ => 13.0,
        };
        final mainText = Text(node.stringOf('value'), style: TextStyle(fontSize: textSize, fontWeight: textBold ? FontWeight.bold : null));
        if (node.props['subtext'] is! String) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: mainText);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [mainText, Text(node.stringOf('subtext'), style: TextStyle(fontSize: textSize - 1, color: Colors.grey))],
          ),
        );
      case 'TextCallout':
        final textCalloutColor = switch (node.stringOf('variant', 'neutral')) {
          'info' => Colors.blue,
          'warning' => Colors.orange,
          'success' => Colors.green,
          'danger' => Colors.red,
          _ => Colors.grey,
        };
        if (node.props['title'] is! String && node.props['description'] is! String) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: textCalloutColor.withValues(alpha: 0.08),
            border: Border(left: BorderSide(color: textCalloutColor, width: 4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (node.props['title'] is String) Text(node.stringOf('title'), style: const TextStyle(fontWeight: FontWeight.bold)),
              if (node.props['description'] is String) Text(node.stringOf('description')),
            ],
          ),
        );
      case 'ImageBlock':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(node.stringOf('src'), height: 180, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(height: 120, color: Colors.grey.shade200, alignment: Alignment.center, child: const Text('图片加载失败')))),
            if (node.props['alt'] is String) Padding(padding: const EdgeInsets.only(top: 4), child: Text(node.stringOf('alt'), style: const TextStyle(color: Colors.grey, fontSize: 13))),
          ],
        );
      case 'ImageGallery':
        // Entries are {src, alt?, details?} maps; plain URL strings
        // are leniently accepted as src-only entries.
        final galleryEntries = <({String src, String? alt, String? details})>[];
        if (node.props['images'] is List) {
          for (final e in (node.props['images'] as List)) {
            if (e is Map && e['src'] is String) {
              galleryEntries.add((src: e['src'] as String, alt: e['alt'] is String ? e['alt'] as String : null, details: e['details'] is String ? e['details'] as String : null));
            } else if (e is String) {
              galleryEntries.add((src: e, alt: null, details: null));
            }
          }
        }
        return SizedBox(
          height: 170,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final entry in galleryEntries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(entry.src, width: 200, height: 140, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 200, height: 140, color: Colors.grey.shade200, alignment: Alignment.center, child: Text(entry.alt ?? '图片加载失败', style: const TextStyle(fontSize: 12)))),
                      ),
                      if (entry.details != null) SizedBox(width: 200, child: Text(entry.details!, style: const TextStyle(color: Colors.grey, fontSize: 12))),
                    ],
                  ),
                ),
            ],
          ),
        );
      case 'ImageText':
        final imageTextSize = node.props['imageSize'] is num ? (node.props['imageSize'] as num).toDouble() : 80.0;
        final imageTextImage = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(node.stringOf('src'), width: imageTextSize, height: imageTextSize, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: imageTextSize, height: imageTextSize, color: Colors.grey.shade200, alignment: Alignment.center, child: Text(node.props['alt'] is String ? node.stringOf('alt') : '图片加载失败', style: const TextStyle(fontSize: 12)))),
        );
        final imageTextBody = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.stringOf('title'), style: TextStyle(fontWeight: node.props['bold'] == true ? FontWeight.bold : null)),
            if (node.props['subtitle'] is String) Text(node.stringOf('subtitle'), style: const TextStyle(color: Colors.grey)),
          ],
        );
        if (node.stringOf('layout', 'horizontal') == 'vertical') {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [imageTextImage, const SizedBox(height: 6), imageTextBody]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [imageTextImage, const SizedBox(width: 8), Expanded(child: imageTextBody)],
        );
      case 'ImageTextLarge':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(node.stringOf('src'), height: 200, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(height: 120, color: Colors.grey.shade200, alignment: Alignment.center, child: Text(node.props['alt'] is String ? node.stringOf('alt') : '图片加载失败', style: const TextStyle(fontSize: 12))))),
            const SizedBox(height: 6),
            Text(node.stringOf('title'), style: TextStyle(fontWeight: node.props['bold'] == true ? FontWeight.bold : null)),
            if (node.props['subtitle'] is String) Text(node.stringOf('subtitle'), style: const TextStyle(color: Colors.grey)),
          ],
        );
      case 'IconText':
        // icon is a string name in this port (React takes an Icon ref).
        final iconSize = switch (node.stringOf('iconSize', 'm')) {
          'xs' => 12.0,
          's' => 16.0,
          'l' => 24.0,
          'xl' => 28.0,
          'sm' => 16.0,
          'md' => 20.0,
          'lg' => 24.0,
          _ => 20.0,
        };
        final iconVariant = node.stringOf('iconVariant', 'neutral');
        final iconColor = switch (iconVariant) {
          'info' => Colors.blue,
          'success' => Colors.green,
          'warning' => Colors.orange,
          'danger' => Colors.red,
          'neutral' => Colors.grey.shade700,
          _ => Colors.grey.shade700,
        };
        final iconWidget = switch (iconVariant) {
          'inverted' => Container(decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: Icon(iconByName(node.stringOf('icon')), size: iconSize, color: Colors.white)),
          'filled' => Container(decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: Icon(iconByName(node.stringOf('icon')), size: iconSize, color: Colors.white)),
          'soft' => Container(decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: Icon(iconByName(node.stringOf('icon')), size: iconSize, color: iconColor)),
          _ => Icon(iconByName(node.stringOf('icon')), size: iconSize, color: iconColor),
        };
        final iconTextBody = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.stringOf('title'), style: TextStyle(fontWeight: node.props['bold'] == true ? FontWeight.bold : null)),
            if (node.props['subtitle'] is String) Text(node.stringOf('subtitle'), style: const TextStyle(color: Colors.grey)),
          ],
        );
        if (node.stringOf('layout', 'horizontal') == 'vertical') {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [iconWidget, const SizedBox(height: 6), iconTextBody]);
        }
        return Row(children: [iconWidget, const SizedBox(width: 6), Expanded(child: iconTextBody)]);
      case 'CodeBlock':
        // Plain text by decision (no highlighting); language is shown
        // as a caption above the code.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.stringOf('language'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(10),
              color: Colors.grey.shade100,
              child: Text(node.stringOf('codeString'), style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            ),
          ],
        );
      case 'InlineHeader':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.stringOf('heading'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (node.props['description'] is String) Text(node.stringOf('description'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        );
      case 'Icon':
        // category picks the fallback icon when the name does not
        // resolve, as in React's categoryFallbacks.
        return Icon(iconByName(node.stringOf('name'), node.props['category'] is String ? node.stringOf('category') : null));
      // ---- Data (remaining) ----
      case 'EditableTable':
        // React shape: name/columns objects/data rows. Cell edits
        // write immediately to form state under
        // "<namespace>:<rowId>:<columnKey>" (namespace = name, or the
        // statement id when name is empty); "Save Changes" assembles
        // the full edited rows and writes them under `name` (skipped
        // when name is empty, since there is no key to submit under).
        final tableName = node.stringOf('name');
        final namespace = tableName.isEmpty ? node.statementId : tableName;
        final columns = _mapList(node.props['columns']);
        final dataRows = _mapList(node.props['data']);
        Object? cellValue(int r, int ci) {
          final key = '$namespace:${dataRows[r]['id'] ?? '$r'}:${columns[ci]['key'] ?? 'default'}';
          if (_stateHas(key)) return _stateValue(key);
          final values = dataRows[r]['values'];
          if (values is List && ci < values.length) return values[ci];
          return null;
        }

        Widget cellEditor(BuildContext context, int r, int ci) {
          final column = columns[ci];
          final key = '$namespace:${dataRows[r]['id'] ?? '$r'}:${column['key'] ?? 'default'}';
          final current = cellValue(r, ci);
          final width = (column['width'] as num?)?.toDouble() ?? 120;
          final type = '${column['type'] ?? 'text'}';
          Widget field;
          switch (type) {
            case 'select':
              final options = _mapList(column['options']);
              final currentValue = current;
              field = DropdownButtonFormField<Object?>(
                initialValue: options.any((o) => o['value'] == currentValue) ? currentValue : null,
                decoration: const InputDecoration(border: InputBorder.none),
                items: [for (final o in options) DropdownMenuItem<Object?>(value: o['value'], child: Text('${o['label'] ?? o['value'] ?? ''}'))],
                onChanged: (v) => _setValue(key, v),
              );
            case 'date-single':
              final initial = current == null ? '' : '$current';
              field = TextFormField(
                initialValue: initial,
                readOnly: true,
                decoration: const InputDecoration(border: InputBorder.none),
                onTap: () async {
                  final parsed = DateTime.tryParse(initial);
                  final picked = await showDatePicker(context: context, initialDate: parsed ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
                  if (picked != null) {
                    _setValue(key, '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                  }
                },
              );
            case 'number':
              field = TextFormField(
                initialValue: current == null ? '' : '$current',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: InputBorder.none),
                onChanged: (v) => _setValue(key, int.tryParse(v) ?? double.tryParse(v) ?? v),
              );
            case 'url':
              field = TextFormField(
                initialValue: current == null ? '' : '$current',
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(border: InputBorder.none),
                onChanged: (v) => _setValue(key, v),
              );
            default:
              field = TextFormField(
                initialValue: current == null ? '' : '$current',
                decoration: const InputDecoration(border: InputBorder.none),
                onChanged: (v) => _setValue(key, v),
              );
          }
          return SizedBox(width: width, child: field);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (columns.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [for (final c in columns) DataColumn(label: Text('${c['header'] ?? ''}'))],
                  rows: [
                    for (var r = 0; r < dataRows.length; r++)
                      DataRow(cells: [for (var ci = 0; ci < columns.length; ci++) DataCell(Builder(builder: (context) => cellEditor(context, r, ci)))]),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _effectiveStreaming
                      ? null
                      : () {
                          if (tableName.isEmpty) return;
                          final rows = [
                            for (var r = 0; r < dataRows.length; r++)
                              {
                                'id': dataRows[r]['id'] ?? '$r',
                                'values': [for (var ci = 0; ci < columns.length; ci++) cellValue(r, ci)],
                              },
                          ];
                          _setValue(tableName, rows);
                        },
                  child: const Text('Save Changes'),
                ),
              ),
            ),
          ],
        );
      case 'AreaChart':
        return _ChartWidget(kind: _ChartKind.area, categories: _strings(node.props['labels']), series: node.nodesOf('series'), palette: _theme.chartPalette, curve: node.stringOf('variant'), xLabel: node.props['xLabel'] is String ? node.stringOf('xLabel') : null, yLabel: node.props['yLabel'] is String ? node.stringOf('yLabel') : null, height: node.props['height'] is num ? (node.props['height'] as num).toDouble() : null);
      case 'RadarChart':
        return RadarChartWidget(categories: _strings(node.props['labels']), series: node.nodesOf('series'), palette: _theme.chartPalette);
      case 'HorizontalBarChart':
        return _ChartWidget(kind: _ChartKind.hbar, categories: _strings(node.props['labels']), series: node.nodesOf('series'), palette: _theme.chartPalette, stacked: node.stringOf('variant') == 'stacked', xLabel: node.props['xLabel'] is String ? node.stringOf('xLabel') : null, yLabel: node.props['yLabel'] is String ? node.stringOf('yLabel') : null);
      case 'RadialChart':
        return RadialChartWidget(labels: _strings(node.props['labels']), values: _numbers(node.props['values']), palette: _theme.chartPalette);
      case 'SingleStackedBarChart':
        return SingleStackedBarWidget(labels: _strings(node.props['labels']), values: _numbers(node.props['values']), palette: _theme.chartPalette);
      case 'ScatterChart':
        return _LabeledChart(
          xLabel: node.props['xLabel'] is String ? node.stringOf('xLabel') : null,
          yLabel: node.props['yLabel'] is String ? node.stringOf('yLabel') : null,
          child: ScatterChartWidget(series: node.nodesOf('datasets'), palette: _theme.chartPalette),
        );
      case 'TagBlock':
        final tagSize = switch (node.stringOf('size', 'md')) {
          'sm' => 11.0,
          'lg' => 15.0,
          _ => 13.0,
        };
        return Wrap(spacing: 8, children: [for (final tag in _strings(node.props['tags'])) Chip(label: Text(tag, style: TextStyle(fontSize: tagSize)))]);
      case 'Tag':
        // icon is a string name in this port (React takes an Icon ref).
        final tagColor = switch (node.stringOf('variant', 'neutral')) {
          'info' => Colors.blue.shade100,
          'success' => Colors.green.shade100,
          'warning' => Colors.orange.shade100,
          'danger' => Colors.red.shade100,
          _ => Colors.grey.shade200,
        };
        final tagFontSize = switch (node.stringOf('size', 'md')) {
          'sm' => 11.0,
          'lg' => 15.0,
          _ => 13.0,
        };
        return Chip(
          label: Text(node.stringOf('text'), style: TextStyle(fontSize: tagFontSize)),
          avatar: node.props['icon'] is String ? Icon(iconByName(node.stringOf('icon')), size: 18) : null,
          backgroundColor: tagColor,
        );
      case 'EntityList':
        // rows are {left, right, rightVariant?} maps; rightVariant
        // 'number' renders the trailing value in tabular figures, as
        // in React. header/footer are row objects.
        final entityDense = node.stringOf('size', 'default') == 'small';
        Widget entityRow(Map map, {bool bold = false}) {
          // rightVariant styles only the trailing value, as in React;
          // the left title never gets tabular figures.
          final isNumber = map['rightVariant'] == 'number';
          final titleStyle = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
          final trailingStyle = (bold || isNumber)
              ? TextStyle(
                  fontWeight: bold ? FontWeight.bold : null,
                  fontFeatures: isNumber ? const [FontFeature.tabularFigures()] : null,
                )
              : null;
          return ListTile(
            dense: entityDense,
            leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
            title: Text(map['left'] is String ? map['left'] as String : '', style: titleStyle),
            trailing: Text(map['right'] is String ? map['right'] as String : (map['right'] == null ? '' : '${map['right']}'), style: trailingStyle),
          );
        }

        final entityChildren = <Widget>[];
        if (node.props['header'] is Map) {
          entityChildren.add(entityRow(node.props['header'] as Map, bold: true));
          entityChildren.add(const Divider(height: 1));
        }
        if (node.props['rows'] is List) {
          for (final row in (node.props['rows'] as List)) {
            if (row is Map) entityChildren.add(entityRow(row));
          }
        }
        if (node.props['footer'] is Map) {
          entityChildren.add(const Divider(height: 1));
          entityChildren.add(entityRow(node.props['footer'] as Map, bold: true));
        }
        return Column(children: entityChildren);
      case 'MetricIndicatorInline':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [Text('${node.props['value']}', style: const TextStyle(fontWeight: FontWeight.bold)), if (node.props['subtext'] is String) Padding(padding: const EdgeInsets.only(left: 8), child: Text(node.stringOf('subtext'), style: const TextStyle(color: Colors.grey))), _trendWidget(node.props['trend'])]),
        );
      case 'MetricIndicatorWithStrikethrough':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [if (node.props['previousValue'] is String) Padding(padding: const EdgeInsets.only(right: 8), child: Text(node.stringOf('previousValue'), style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey))), Text('${node.props['value']}', style: const TextStyle(fontWeight: FontWeight.bold)), if (node.props['subtext'] is String) Padding(padding: const EdgeInsets.only(left: 8), child: Text(node.stringOf('subtext'), style: const TextStyle(color: Colors.grey))), _trendWidget(node.props['trend'])]),
        );
      // ---- Form (remaining) ----
      case 'FormControl':
        // The mapper does not enforce the input union: any node is
        // accepted as `input`. Rules are validated live with
        // validateRules, but only for touched fields: a field counts
        // as touched when its name key exists in form state (i.e. the
        // user changed it), so untouched fields never show an error.
        // There is no submit gate; hosts can call validateRules
        // directly for submit-time validation.
        final inputNode = node.nodeOf('input');
        final inputRules = inputNode?.props['rules'];
        final requiredMark = inputRules is Map && inputRules['required'] == true ? ' *' : '';
        String? validationError;
        if (inputNode != null && inputRules is Map) {
          final inputName = inputNode.stringOf('name');
          if (inputName.isNotEmpty && _stateHas(inputName)) {
            validationError = validateRules(inputRules, _stateValue(inputName));
          }
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text('${node.stringOf('label')}$requiredMark', style: const TextStyle(fontWeight: FontWeight.bold)), if (inputNode != null) _buildNode(inputNode), if (validationError != null) Text(validationError, style: const TextStyle(color: Colors.red, fontSize: 13)), if (node.props['hint'] is String) Text(node.stringOf('hint'), style: const TextStyle(color: Colors.grey, fontSize: 13))],
          ),
        );
      case 'Label':
        return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(node.stringOf('text'), style: const TextStyle(fontWeight: FontWeight.bold)));
      case 'TextArea':
        final areaKey = node.stringOf('name');
        final initial = _stateHas(areaKey) ? '${_stateValue(areaKey)}' : (node.props['value'] == null ? '' : '${node.props['value']}');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextFormField(
            initialValue: initial,
            maxLines: node.props['rows'] is num ? (node.props['rows'] as num).toInt() : 4,
            enabled: !_effectiveStreaming,
            decoration: InputDecoration(hintText: node.props['placeholder'] is String ? node.stringOf('placeholder') : null, border: const OutlineInputBorder()),
            onChanged: (v) => _setValue(areaKey, v),
          ),
        );
      case 'DatePicker':
        // mode range is accepted but renders as the single-date
        // picker: no range UI is built in this port (documented
        // deviation).
        final dateKey = node.stringOf('name');
        final value = _stateHas(dateKey) ? '${_stateValue(dateKey)}' : (node.props['value'] is String ? node.stringOf('value') : null);
        return DatePickerField(
          stateKey: dateKey,
          value: value,
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      case 'Slider':
        // Value is an array of numbers; single-thumb use takes the
        // first element, and writes back a one-element array.
        final sliderKey = node.stringOf('name');
        final sliderNumbers = _numbers(_stateHas(sliderKey) ? _stateValue(sliderKey) : (node.props['value'] ?? node.props['defaultValue']));
        final sliderMin = node.props['min'] is num ? (node.props['min'] as num).toDouble() : 0.0;
        final sliderMax = node.props['max'] is num ? (node.props['max'] as num).toDouble() : 100.0;
        final sliderStep = node.props['step'] is num ? (node.props['step'] as num).toDouble() : null;
        return SliderField(
          label: node.props['label'] is String ? node.stringOf('label') : null,
          stateKey: sliderKey,
          value: sliderNumbers.isNotEmpty ? sliderNumbers.first : sliderMin,
          min: sliderMin,
          max: sliderMax,
          divisions: node.stringOf('variant') == 'discrete' && sliderStep != null && sliderStep > 0 ? ((sliderMax - sliderMin) / sliderStep).round().clamp(1, 1000000) : null,
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, [v]);
          },
        );
      case 'CheckBoxGroup':
        final checkKey = node.stringOf('name');
        return MultiSelectGroupWidget(
          items: node.nodesOf('items'),
          stateKey: checkKey,
          stateValue: _stateHas(checkKey) ? _stateValue(checkKey) : null,
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      case 'SwitchGroup':
        final switchKey = node.stringOf('name');
        return SwitchGroupWidget(
          items: node.nodesOf('items'),
          stateKey: switchKey,
          stateValue: _stateHas(switchKey) ? _stateValue(switchKey) : null,
          variant: node.stringOf('variant', 'clear'),
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      case 'RadioGroup':
        final radioKey = node.stringOf('name');
        return SingleSelectGroupWidget(
          items: node.nodesOf('items'),
          stateKey: radioKey,
          stateValue: _stateHas(radioKey) ? _stateValue(radioKey) : node.props['defaultValue'],
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      case 'OptionCards':
        final cardsKey = node.stringOf('name');
        return SingleSelectGroupWidget(
          items: node.nodesOf('items'),
          stateKey: cardsKey,
          stateValue: _stateHas(cardsKey) ? _stateValue(cardsKey) : node.props['defaultValue'],
          multi: node.stringOf('type', 'single') == 'multiple',
          asCards: true,
          buildNode: _buildNode,
          enabled: !_effectiveStreaming,
          onChanged: (k, v) {
            if (k != null) _setValue(k, v);
          },
        );
      // ---- Actions (remaining) ----
      case 'Buttons':
        final buttons = [for (final c in node.nodesOf('buttons')) _buildNode(c)];
        if (node.stringOf('direction', 'row') == 'column') {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: buttons);
        }
        return Wrap(spacing: 8, children: buttons);
      case 'IconButton':
        // icon is a string name in this port (React takes an Icon ref);
        // name is used as the tooltip.
        final iconButtonSize = switch (node.stringOf('size', 'medium')) {
          'extra-small' => 16.0,
          'small' => 20.0,
          'large' => 28.0,
          _ => 24.0,
        };
        final iconButtonColor = switch (node.stringOf('variant', 'secondary')) {
          'primary' => Colors.blue,
          'tertiary' => null,
          _ => Colors.grey.shade700,
        };
        return Tooltip(
          message: node.stringOf('name'),
          child: IconButton(
            icon: Icon(iconByName(node.stringOf('icon')), size: iconButtonSize),
            color: iconButtonColor,
            style: node.stringOf('shape', 'circle') == 'square' ? IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))) : null,
            onPressed: _effectiveStreaming ? null : () => _dispatch(node.props['action']),
          ),
        );
      // ---- Dialogue (remaining) ----
      case 'ListBlock':
        final listItems = node.nodesOf('items');
        Widget listBody;
        if (node.stringOf('variant', '') == 'number') {
          // Numbered leading is a ListBlock-level concern, so this
          // path renders items directly and bypasses custom ListItem
          // registry builders for them.
          listBody = Column(
            children: [
              for (var i = 0; i < listItems.length; i++) _numberedListTile(listItems[i], i + 1),
            ],
          );
        } else {
          listBody = Column(children: [for (final c in listItems) _buildNode(c)]);
        }
        if (node.stringOf('size', 'default') == 'small') {
          listBody = ListTileTheme(data: const ListTileThemeData(dense: true), child: listBody);
        }
        return listBody;
      case 'ListItem':
        final listImage = node.props['image'];
        Widget? listLeading;
        if (listImage is Map && listImage['src'] is String) {
          final alt = listImage['alt'] is String ? listImage['alt'] as String : '图片加载失败';
          listLeading = ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(listImage['src'] as String, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 48, height: 48, color: Colors.grey.shade200, alignment: Alignment.center, child: Text(alt, style: const TextStyle(fontSize: 10)))),
          );
        }
        return ListTile(
          leading: listLeading ?? const Text('•'),
          title: Text(node.stringOf('title')),
          subtitle: node.props['subtitle'] is String ? Text(node.stringOf('subtitle')) : null,
          trailing: node.props['actionLabel'] is String
              ? TextButton(onPressed: _effectiveStreaming ? null : () => _dispatch(node.props['action']), child: Text(node.stringOf('actionLabel')))
              : null,
          onTap: node.props['action'] != null && node.props['actionLabel'] is! String ? () => _dispatch(node.props['action']) : null,
        );
      // ---- Composite cards ----
      // Blocks share items/layout/responsive/action/gap (React 0.18.1
      // schemas); `responsive` switches the grid between container
      // breakpoints (see _cardGrid).
      case 'SnippetCardBlock':
      case 'OverviewCardBlock':
      case 'ContextCardBlock':
      case 'CompositeCardBlock':
      case 'VisualCardBlock':
        return _cardBlock(node);
      case 'SnippetCardItem':
        final lhs = node.nodeOf('lhs');
        final rhs = node.nodeOf('rhs');
        return _cardItemCard([if (lhs != null) _buildNode(lhs), if (rhs != null) _buildNode(rhs)]);
      case 'OverviewCardItem':
        final top = node.nodeOf('top');
        final bottom = node.nodeOf('bottom');
        return _cardItemCard([if (top != null) _buildNode(top), if (bottom != null) _buildNode(bottom)]);
      case 'ContextCardItem':
        return _bgCardItem(
          node,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (node.props['title'] is String) Text(node.stringOf('title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (node.nodeOf('title') != null) _buildNode(node.nodeOf('title')!),
              if (node.props['body'] is String) Padding(padding: const EdgeInsets.only(top: 4), child: Text(node.stringOf('body'))),
            ],
          ),
        );
      case 'CompositeCardItem':
        final header = node.nodeOf('header');
        final footer = node.props['footer'];
        final price = footer is Map ? footer['price'] : null;
        final button = footer is Map ? footer['button'] : null;
        return _cardItemCard([
          if (header != null) _buildNode(header),
          for (final c in node.nodesOf('body')) _buildNode(c),
          if (price is ElementNode || button is ElementNode)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [if (price is ElementNode) Expanded(child: _buildNode(price)), if (button is ElementNode) _buildNode(button)]),
            ),
        ]);
      case 'VisualCardItem':
        final body = node.nodeOf('body');
        final tag = node.nodeOf('tag');
        return _bgCardItem(
          node,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [if (body != null) _buildNode(body), if (tag != null) Padding(padding: const EdgeInsets.only(top: 6), child: _buildNode(tag))],
          ),
        );
      default:
        // Col, Series, Slice, ScatterSeries, Point, SelectItem, ChipItem,
        // FollowUpItem, CheckBoxItem, RadioItem, SwitchItem, OptionCard
        // are only meaningful inside their parent; rendered alone they
        // are empty.
        return const SizedBox.shrink();
    }
  }

  // ---- Composite card helpers ----

  Widget _cardItemCard(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_theme.cardRadius)),
      margin: const EdgeInsets.all(4),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
    );
  }

  /// Gap for card blocks: a number is logical pixels, a string uses the
  /// React gap scale, absent gap defaults to 12 (React's
  /// --openui-small/medium-card-gap, i.e. space-m).
  double _cardGap(ElementNode node) {
    final gap = node.props['gap'];
    if (gap is num) return gap.toDouble();
    if (gap is String) return _gapValue(gap);
    return 12;
  }

  Widget _cardBlock(ElementNode node) {
    // SnippetCardBlock is grid-only in React; the mapper records a
    // type-mismatch for a carousel layout and falls back to grid.
    final layout = node.stringOf('layout', 'grid');
    final effectiveLayout = node.component == 'SnippetCardBlock' && layout == 'carousel' ? 'grid' : layout;
    final gap = _cardGap(node);
    final items = [for (final c in node.nodesOf('items')) _buildNode(c)];
    final Widget content;
    if (effectiveLayout == 'carousel') {
      content = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final w in items) Padding(padding: EdgeInsets.only(right: gap), child: SizedBox(width: 280, child: w))]),
      );
    } else {
      content = _cardGrid(items, gap, node.props['responsive'] != false);
    }
    final Widget block = Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: content);
    if (node.props['action'] != null) {
      return InkWell(onTap: () => _dispatch(node.props['action']), child: block);
    }
    return block;
  }

  /// React's card-block grid (CardBlockLayout + small/medium scss).
  /// Responsive (the default) uses container breakpoints: 1 column
  /// under 30rem (480), 2 under 48rem (768), rows above that.
  /// Non-responsive always uses rows. Rows hold at most 3 cards,
  /// balanced so the grid never ends with a lonely single card.
  /// Carousel items are 280 wide (React's 17.5rem); the grid's
  /// unbounded-width fallback keeps the old 280-wide Wrap.
  Widget _cardGrid(List<Widget> items, double gap, bool responsive) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite) {
          return Wrap(spacing: gap, runSpacing: gap, children: [for (final w in items) SizedBox(width: 280, child: w)]);
        }
        if (responsive && width < 480) {
          return Wrap(spacing: gap, runSpacing: gap, children: [for (final w in items) SizedBox(width: width, child: w)]);
        }
        if (responsive && width < 768) {
          final colWidth = (width - gap) / 2;
          return Wrap(spacing: gap, runSpacing: gap, children: [for (final w in items) SizedBox(width: colWidth, child: w)]);
        }
        final rows = _rowConfiguration(items.length, 3);
        final rowWidgets = <Widget>[];
        var index = 0;
        for (final count in rows) {
          final rowItems = items.sublist(index, index + count);
          index += count;
          rowWidgets.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < rowItems.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(child: rowItems[i]),
                ],
              ],
            ),
          );
        }
        final spaced = <Widget>[];
        for (var i = 0; i < rowWidgets.length; i++) {
          if (i > 0) spaced.add(SizedBox(height: gap));
          spaced.add(rowWidgets[i]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced);
      },
    );
  }

  /// Port of React's smallCardBlockUtils.getRowConfiguration: splits
  /// n items into rows of at most maxPerRow, avoiding a lonely single
  /// card in the last row when possible.
  List<int> _rowConfiguration(int n, int maxPerRow) {
    if (n <= 0) return [];
    if (n == 1) return [1];
    if (maxPerRow == 2) {
      final fullRows = n ~/ 2;
      final result = List<int>.filled(fullRows, 2, growable: true);
      if (n % 2 == 1) result.add(1);
      return result;
    }
    if (n % 3 == 0) return List<int>.filled(n ~/ 3, 3);
    if (n % 3 == 2) {
      final threes = n ~/ 3;
      final result = List<int>.filled(threes, 3, growable: true);
      result.insert((result.length / 2).ceil(), 2);
      return result;
    }
    final threes = (n - 4) ~/ 3;
    return [...List<int>.filled(threes, 3), 2, 2];
  }

  /// Card item with an optional gray background or background image.
  /// With a bg image the content sits on a translucent white scrim so
  /// text stays readable; bgImageAlt (when given) is the image's
  /// semantic label, as React's img alt.
  Widget _bgCardItem(ElementNode node, Widget content) {
    final bgImage = node.props['bgImageSrc'] is String ? node.stringOf('bgImageSrc') : null;
    final bgAlt = node.props['bgImageAlt'] is String ? node.stringOf('bgImageAlt') : null;
    final gray = node.stringOf('bgColor') == 'gray';
    if (bgImage == null) {
      return Card(
        color: gray ? Colors.grey.shade200 : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_theme.cardRadius)),
        margin: const EdgeInsets.all(4),
        child: Padding(padding: const EdgeInsets.all(12), child: content),
      );
    }
    final image = Image.network(bgImage, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const SizedBox.shrink());
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_theme.cardRadius)),
      margin: const EdgeInsets.all(4),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: bgAlt != null ? Semantics(label: bgAlt, child: image) : image),
          Container(color: Colors.white.withValues(alpha: 0.75), padding: const EdgeInsets.all(12), child: content),
        ],
      ),
    );
  }

  List<String> _strings(Object? v) {
    if (v is List) return v.map((e) => '$e').toList();
    return const [];
  }

  /// Object props arrive as Map<dynamic, dynamic> from the Lang
  /// evaluator; normalize keys to strings for column/row objects.
  Map<String, Object?> _stringMap(Object? v) {
    if (v is Map) return Map<String, Object?>.fromEntries(v.entries.map((e) => MapEntry('${e.key}', e.value)));
    return const {};
  }

  List<Map<String, Object?>> _mapList(Object? v) {
    if (v is List) return [for (final e in v) if (e is Map) _stringMap(e)];
    return const [];
  }

  /// Copies [node], attaching [sources] as the hidden `__sources` prop
  /// on every TextContent descendant, so a chat Card's sources back
  /// inline [n] citations. A nested Card with its own sources re-runs
  /// this transform and overwrites, so the innermost Card wins. The
  /// prop is renderer-only: it is never in a ComponentDef or prompt.
  ElementNode _withSources(ElementNode node, List<Map<String, Object?>> sources) {
    final props = <String, Object?>{};
    for (final entry in node.props.entries) {
      final v = entry.value;
      if (v is ElementNode) {
        props[entry.key] = _withSources(v, sources);
      } else if (v is List) {
        props[entry.key] = [for (final e in v) e is ElementNode ? _withSources(e, sources) : e];
      } else {
        props[entry.key] = v;
      }
    }
    if (node.component == 'TextContent') props['__sources'] = sources;
    return ElementNode(node.component, props, node.statementId);
  }

  List<double> _numbers(Object? v) {
    if (v is List) return v.map((e) => (e as num?)?.toDouble() ?? 0).toList();
    return const [];
  }

  // ---- Flex layout (Stack / Card) ----
  // Gap values follow React's --openui-space scale (none 0, xs 6,
  // s 8, m 12, l 18, xl 24, 2xl 36). When gap is absent, React's
  // renderers fall back to "m" (12).
  double _gapValue(String? gap) => switch (gap) {
        'none' => 0,
        'xs' => 6,
        's' => 8,
        'm' => 12,
        'l' => 18,
        'xl' => 24,
        '2xl' => 36,
        _ => 0,
      };

  Widget _flexLayout(ElementNode node, List<Widget> children) {
    final direction = node.stringOf('direction', 'column');
    // Absent gap falls back to "m" (12), as in React's renderers.
    final gap = node.props['gap'] is String ? _gapValue(node.stringOf('gap')) : 12.0;
    final alignName = node.props['align'] is String ? node.stringOf('align') : (direction == 'row' ? 'start' : 'stretch');
    final crossAxis = switch (alignName) {
      'start' => CrossAxisAlignment.start,
      'center' => CrossAxisAlignment.center,
      'end' => CrossAxisAlignment.end,
      'baseline' => CrossAxisAlignment.baseline,
      _ => CrossAxisAlignment.stretch,
    };
    final mainAxis = switch (node.stringOf('justify', 'start')) {
      'center' => MainAxisAlignment.center,
      'end' => MainAxisAlignment.end,
      'between' => MainAxisAlignment.spaceBetween,
      'around' => MainAxisAlignment.spaceAround,
      'evenly' => MainAxisAlignment.spaceEvenly,
      _ => MainAxisAlignment.start,
    };
    final textBaseline = crossAxis == CrossAxisAlignment.baseline ? TextBaseline.alphabetic : null;
    if (node.props['wrap'] == true) {
      final wrapAlignment = switch (node.stringOf('justify', 'start')) {
        'center' => WrapAlignment.center,
        'end' => WrapAlignment.end,
        'between' => WrapAlignment.spaceBetween,
        'around' => WrapAlignment.spaceAround,
        'evenly' => WrapAlignment.spaceEvenly,
        _ => WrapAlignment.start,
      };
      return Wrap(
        direction: direction == 'row' ? Axis.horizontal : Axis.vertical,
        spacing: gap,
        runSpacing: gap,
        alignment: wrapAlignment,
        children: children,
      );
    }
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(direction == 'row' ? SizedBox(width: gap) : SizedBox(height: gap));
      spaced.add(children[i]);
    }
    if (direction == 'row') {
      return Row(mainAxisAlignment: mainAxis, crossAxisAlignment: crossAxis, textBaseline: textBaseline, children: spaced);
    }
    return Column(mainAxisAlignment: mainAxis, crossAxisAlignment: crossAxis, textBaseline: textBaseline, children: spaced);
  }

  // ---- Metric trend ----
  // trend is a {direction: up/down, value: number} map.
  Widget _trendWidget(Object? trend) {
    if (trend is! Map) return const SizedBox.shrink();
    final up = trend['direction'] == 'up';
    final value = trend['value'];
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text('${up ? '▲' : '▼'}${value ?? ''}', style: TextStyle(color: up ? Colors.green : Colors.red)),
    );
  }

  // ---- Numbered list tile (ListBlock variant=number) ----
  Widget _numberedListTile(ElementNode item, int index) {
    return ListTile(
      leading: CircleAvatar(radius: 12, child: Text('$index', style: const TextStyle(fontSize: 12))),
      title: Text(item.stringOf('title')),
      subtitle: item.props['subtitle'] is String ? Text(item.stringOf('subtitle')) : null,
      trailing: item.props['actionLabel'] is String
          ? TextButton(onPressed: _effectiveStreaming ? null : () => _dispatch(item.props['action']), child: Text(item.stringOf('actionLabel')))
          : null,
      onTap: item.props['action'] != null && item.props['actionLabel'] is! String ? () => _dispatch(item.props['action']) : null,
    );
  }
}

/// Axis labels for charts: yLabel above, xLabel below, both small grey.
class _LabeledChart extends StatelessWidget {
  const _LabeledChart({required this.child, this.xLabel, this.yLabel});
  final Widget child;
  final String? xLabel;
  final String? yLabel;
  @override
  Widget build(BuildContext context) {
    if (xLabel == null && yLabel == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (yLabel != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(yLabel!, style: const TextStyle(color: Colors.grey, fontSize: 12))),
        child,
        if (xLabel != null) Padding(padding: const EdgeInsets.only(top: 4), child: Center(child: Text(xLabel!, style: const TextStyle(color: Colors.grey, fontSize: 12)))),
      ],
    );
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
  const _ModalWidget({required this.node, required this.buildNode, this.open = true, this.size = 'md'});
  final ElementNode node;
  final Widget Function(ElementNode) buildNode;
  final bool open;
  final String size;
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
    // open flipping false -> true re-arms a previously closed dialog.
    if (widget.open && !oldWidget.open) {
      _dismissed = false;
      _dialogShown = false;
      _showScheduled = false;
    }
    _scheduleShow();
  }

  void _scheduleShow() {
    if (!widget.open || _dismissed || _dialogShown || _showScheduled) return;
    _showScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showScheduled = false;
      if (!mounted || _dismissed || _dialogShown) return;
      _dialogShown = true;
      final dialogWidth = switch (widget.size) {
        'sm' => 280.0,
        'lg' => 520.0,
        _ => 400.0,
      };
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: widget.node.props['title'] is String ? Text(widget.node.stringOf('title')) : null,
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final c in widget.node.nodesOf('children')) widget.buildNode(c)],
              ),
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
// MarkDownRenderer now uses the flutter_markdown_plus package (full
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
  const _SelectWidget({required this.items, required this.stateKey, required this.stateValue, this.placeholder, this.size = 'medium', required this.onChanged, this.enabled = true});
  final List<ElementNode> items;
  final String? stateKey;
  final Object? stateValue;
  final String? placeholder;
  final String size;
  final bool enabled;
  final void Function(String?, Object?) onChanged;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    // No selection yet shows the placeholder rather than pre-selecting
    // the first item; React defaults the placeholder to "Select...".
    final values = items.map((o) => o.props['value']).toList();
    final current = stateValue != null && values.contains(stateValue) ? stateValue : null;
    final fontSize = switch (size) {
      'small' => 13.0,
      'large' => 17.0,
      _ => 15.0,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<Object>(
        initialValue: current,
        style: TextStyle(fontSize: fontSize),
        decoration: InputDecoration(hintText: placeholder ?? 'Select...', border: const OutlineInputBorder()),
        items: [for (final o in items) DropdownMenuItem(value: o.props['value'], child: Text(o.stringOf('label')))],
        onChanged: enabled ? (v) => onChanged(stateKey, v) : null,
      ),
    );
  }
}

class _ChipsWidget extends StatefulWidget {
  const _ChipsWidget({required this.items, required this.stateKey, required this.stateValue, this.type = 'multiple', required this.onChanged, this.enabled = true});
  final List<ElementNode> items;
  final String? stateKey;
  final Object? stateValue;
  // single | multiple (React default multiple).
  final String type;
  final bool enabled;
  final void Function(String?, Object?) onChanged;
  @override
  State<_ChipsWidget> createState() => _ChipsWidgetState();
}

class _ChipsWidgetState extends State<_ChipsWidget> {
  Object? _local;
  final _localSet = <Object?>{};
  @override
  Widget build(BuildContext context) {
    final multi = widget.type == 'multiple';
    final selectedSingle = multi ? null : (widget.stateValue ?? _local);
    final selectedSet = multi
        ? (widget.stateValue is List
            ? (widget.stateValue as List).toSet()
            : widget.stateValue != null
                ? {widget.stateValue}
                : _localSet)
        : const <Object?>{};
    return Wrap(
      spacing: 8,
      children: [
        for (final item in widget.items)
          ChoiceChip(
            label: Text(item.stringOf('label')),
            // icon is a string name in this port (React takes an Icon
            // ref); see the ChipItem def in library.dart.
            avatar: item.props['icon'] is String ? Icon(iconByName(item.stringOf('icon')), size: 18) : null,
            selected: multi ? selectedSet.contains(item.props['value']) : selectedSingle == item.props['value'],
            onSelected: (widget.enabled && item.props['disabled'] != true)
                ? (v) {
                    final value = item.props['value'];
                    if (widget.stateKey != null) {
                      if (multi) {
                        final next = Set.of(selectedSet);
                        if (v) {
                          next.add(value);
                        } else {
                          next.remove(value);
                        }
                        widget.onChanged(widget.stateKey, next.toList());
                      } else if (v) {
                        widget.onChanged(widget.stateKey, value);
                      }
                    } else {
                      setState(() {
                        if (multi) {
                          if (v) {
                            _localSet.add(value);
                          } else {
                            _localSet.remove(value);
                          }
                        } else if (v) {
                          _local = value;
                        }
                      });
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
          tabs: [for (final item in widget.items) Tab(text: item.stringOf('trigger'))],
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
                    children: [for (final c in item.nodesOf('content')) widget.buildNode(c)],
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
  const _ChartWidget({required this.kind, required this.categories, required this.series, this.palette = _palette, this.stacked = false, this.curve, this.xLabel, this.yLabel, this.height});
  final _ChartKind kind;
  final List<String> categories;
  final List<ElementNode> series;
  final List<Color> palette;
  final bool stacked;
  final String? curve;
  final String? xLabel;
  final String? yLabel;
  final double? height;
  @override
  Widget build(BuildContext context) {
    final Widget chart;
    switch (kind) {
      case _ChartKind.bar:
        chart = FlBarChartWidget(categories: categories, series: series, palette: palette, stacked: stacked, height: height ?? 220);
      case _ChartKind.hbar:
        chart = FlBarChartWidget(categories: categories, series: series, palette: palette, horizontal: true, stacked: stacked, height: height ?? 220);
      case _ChartKind.line:
        chart = FlLineChartWidget(categories: categories, series: series, palette: palette, curved: curve == 'natural', step: curve == 'step', height: height ?? 220);
      case _ChartKind.area:
        chart = FlLineChartWidget(categories: categories, series: series, palette: palette, area: true, curved: curve == 'natural', step: curve == 'step', height: height ?? 220);
    }
    return _LabeledChart(xLabel: xLabel, yLabel: yLabel, child: chart);
  }
}

class _PieWidget extends StatelessWidget {
  const _PieWidget({required this.labels, required this.values, this.variant = 'pie', this.appearance = 'circular', this.palette = _palette});
  final List<String> labels;
  final List<double> values;
  final String variant;
  final String appearance;
  final List<Color> palette;
  @override
  Widget build(BuildContext context) => FlPieChartWidget(labels: labels, values: values, variant: variant, appearance: appearance, palette: palette);
}
