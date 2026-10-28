import 'dart:async';

import 'package:flutter/foundation.dart';

import 'lang.dart';
import 'registry.dart';
import 'theme.dart';

class ActionEvent {
  const ActionEvent(this.type, this.args, this.formState);
  final String type;
  final List<Object?> args;
  final Map<String, Object?> formState;
}

/// Runs a Query or Mutation tool: `tool` is the first argument of the
/// Query/Mutation statement, `params` is its (object) second argument.
typedef OpenUIToolProvider = Future<Object?> Function(String tool, Map<String, Object?> params);

/// Owns everything a renderer needs beyond the widget tree: form state,
/// Query data and failure state, action dispatch, and the streaming
/// buffer. The renderer in controller mode is a thin view over this
/// object: it rebuilds when the controller notifies, and every form
/// change or action goes back through here, so hosts can drive the
/// same UI from outside the widget tree (and read [formState] after
/// any interaction).
///
/// Query rules are the renderer's old rules, unchanged: a failed fetch
/// is not retried until an explicit `@Run`, and a failed Mutation
/// stops the rest of an action list.
class OpenUIController extends ChangeNotifier {
  OpenUIController({
    required this.library,
    this.toolProvider,
    this.theme,
    this.registry,
    Map<String, Object?> initialState = const {},
  }) : _formState = Map.of(initialState) {
    _parser = StreamingParser(library, state: _formState, queryData: _queryData);
  }

  final OpenUILibrary library;
  final OpenUIToolProvider? toolProvider;
  final OpenUIThemeData? theme;
  final ComponentRegistry? registry;

  OpenUIThemeData get effectiveTheme => theme ?? OpenUIThemeData.light();

  Stream<ActionEvent> get onAction => _actionController.stream;
  Stream<OpenUIError> get onError => _errorController.stream;

  Map<String, Object?> get formState => Map.of(_formState);
  Map<String, Object?> get queryData => Map.of(_queryData);
  bool get isStreaming => _streaming;

  final Map<String, Object?> _formState;
  final Map<String, Object?> _queryData = {};
  final Map<String, String> _queryParams = {};
  final Map<String, String> _fetchingParams = {};
  final Map<String, String> _failedParams = {};
  final Map<String, Object> _queryErrors = {};
  final Map<String, QueryRequest> _pendingFetches = {};
  late final StreamingParser _parser;
  ParseResult? _lastResult;
  var _lastQueries = <QueryRequest>[];
  var _lastMutations = <MutationRequest>[];
  var _streaming = false;
  var _disposed = false;
  final _actionController = StreamController<ActionEvent>.broadcast();
  final _errorController = StreamController<OpenUIError>.broadcast();

  /// Append a chunk of OpenUI Lang. Notifies listeners so a renderer
  /// in controller mode rebuilds with the new (autoclosed) display.
  void push(String chunk) {
    _streaming = true;
    _lastResult = _parser.push(chunk);
    _lastQueries = _lastResult!.queries;
    _lastMutations = _lastResult!.mutations;
    _scheduleFetches(_lastResult!.queries);
    _notify();
  }

  /// End streaming and parse the full buffer. Notifies listeners.
  ParseResult finish() {
    _streaming = false;
    _lastResult = _parser.finish();
    _lastQueries = _lastResult!.queries;
    _lastMutations = _lastResult!.mutations;
    _scheduleFetches(_lastResult!.queries);
    _notify();
    return _lastResult!;
  }

  /// Re-parse the current buffer with the current form state and
  /// Query data. For renderer use during build: it schedules fetches
  /// but does NOT notify (fetch completion notifies later).
  ParseResult parseCurrent() {
    _lastResult = _streaming ? _parser.push('') : _parser.finish();
    _lastQueries = _lastResult!.queries;
    _lastMutations = _lastResult!.mutations;
    _scheduleFetches(_lastResult!.queries);
    return _lastResult!;
  }

  /// Set one form value (a bound Input/Select/Chips change). Re-parses
  /// so a Query whose parameters depend on the value refetches, then
  /// notifies listeners.
  void setFormValue(String key, Object? value) {
    _formState[key] = value;
    parseCurrent();
    _notify();
  }

  String _paramsKey(Map<String, Object?> params) {
    final keys = params.keys.toList()..sort();
    return keys.map((k) => '$k=${params[k]}').join('&');
  }

  void _scheduleFetches(List<QueryRequest> requests) {
    final provider = toolProvider;
    if (provider == null) return;
    for (final req in requests) {
      final key = _paramsKey(req.params);
      if (_queryData.containsKey(req.statementName) && _queryParams[req.statementName] == key) continue;
      if (_fetchingParams[req.statementName] == key) continue;
      // A failed fetch is not retried on every build; only an explicit
      // @Run refetch (which clears _failedParams) retries it.
      if (_failedParams[req.statementName] == key) continue;
      if (_pendingFetches.containsKey(req.statementName) && _paramsKey(_pendingFetches[req.statementName]!.params) == key) continue;
      _pendingFetches[req.statementName] = req;
      unawaited(_fetchQuery(req));
    }
  }

  Future<void> _fetchQuery(QueryRequest req) async {
    final provider = toolProvider;
    if (provider == null) return;
    final key = _paramsKey(req.params);
    _fetchingParams[req.statementName] = key;
    try {
      final result = await provider(req.tool, req.params);
      if (_disposed) return;
      _pendingFetches.remove(req.statementName);
      _queryData[req.statementName] = result;
      _queryParams[req.statementName] = key;
      _queryErrors.remove(req.statementName);
      _failedParams.remove(req.statementName);
      _fetchingParams.remove(req.statementName);
      _notify();
    } catch (e) {
      if (_disposed) return;
      _pendingFetches.remove(req.statementName);
      _fetchingParams.remove(req.statementName);
      _failedParams[req.statementName] = key;
      _queryErrors[req.statementName] = e;
      _errorController.add(OpenUIError('tool-error', '${req.tool}: $e'));
      _notify();
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
    _scheduleFetches(current);
  }

  /// Dispatch an action value (or a list of them). Returns false only
  /// when a Mutation failed, which stops the rest of a list.
  Future<bool> runAction(Object? action) async {
    if (action is List) {
      for (final a in action) {
        final ok = await _runSingle(a);
        if (!ok) return false;
      }
      return true;
    }
    return _runSingle(action);
  }

  Future<bool> _runSingle(Object? action) async {
    if (action is! ActionValue) return true;
    switch (action.name) {
      case 'Set':
        if (action.args.isNotEmpty && action.args.first is String) {
          _formState[action.args.first as String] = action.args.length > 1 ? action.args[1] : null;
          parseCurrent();
          _notify();
        }
        _actionController.add(ActionEvent('set', action.args, Map.of(_formState)));
        return true;
      case 'Reset':
        for (final a in action.args) {
          if (a is String) _formState.remove(a);
        }
        parseCurrent();
        _notify();
        _actionController.add(ActionEvent('reset', action.args, Map.of(_formState)));
        return true;
      case 'Run':
        if (action.args.isEmpty || action.args.first is! String) return true;
        final ref = action.args.first as String;
        MutationRequest? mutation;
        for (final m in _lastMutations) {
          if (m.statementName == ref) mutation = m;
        }
        if (mutation != null) {
          final provider = toolProvider;
          _actionController.add(ActionEvent('run', action.args, Map.of(_formState)));
          if (provider == null) return true;
          try {
            final result = await provider(mutation.tool, mutation.params);
            _actionController.add(ActionEvent('mutationResult', [mutation.tool, result], Map.of(_formState)));
            _refetchAllQueries();
            _notify();
            return true;
          } catch (e) {
            _errorController.add(OpenUIError('tool-error', '${mutation.tool}: $e'));
            _actionController.add(ActionEvent('mutationError', [mutation.tool, '$e'], Map.of(_formState)));
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
          _actionController.add(ActionEvent('run', action.args, Map.of(_formState)));
          return true;
        }
        _actionController.add(ActionEvent('run', action.args, Map.of(_formState)));
        return true;
      case 'ToAssistant':
        _actionController.add(ActionEvent('toAssistant', action.args, Map.of(_formState)));
        return true;
      case 'OpenUrl':
        _actionController.add(ActionEvent('openUrl', action.args, Map.of(_formState)));
        return true;
      default:
        _actionController.add(ActionEvent(action.name, action.args, Map.of(_formState)));
        return true;
    }
  }

  /// Notifies unless disposed; fetches that complete after dispose are
  /// dropped instead of throwing on a closed stream or notifier.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _actionController.close();
    _errorController.close();
    super.dispose();
  }
}
