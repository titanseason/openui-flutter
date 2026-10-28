// Pure Dart core for OpenUI Lang 1.0 (subset).
//
// Supported: one assignment statement per line, positional arguments,
// literals, lists, objects, field access, index access, references,
// $variables, ternary, binary operators (+ - * / % == != < <= > >= && || !),
// forward references, last-definition-wins, root entry + fallback,
// @actions, custom functions, built-in functions, Query()/Mutation()
// statements (collected as requests for the host's tool provider; the
// renderer supplies results through `queryData`), structured error codes,
// and streaming with autocloser (see StreamingParser).
//
// Note: `OpenUILibrary.registry` (Task 3) links this file to Flutter
// widgets through registry.dart, so this file is no longer importable
// from a pure-Dart program on its own. The parser and evaluator
// themselves use no Flutter API; only the registry field (a builder
// map) carries widget builders. See the Task 3 report for the
// trade-off discussion.

import 'dart:convert';

import 'registry.dart';

enum PropType { string, number, boolean, list, node, nodeList, any, action, actionList }

class PropDef {
  const PropDef(this.name, this.type, {this.required = false, this.defaultValue});
  final String name;
  final PropType type;
  final bool required;
  final Object? defaultValue;
}

class ComponentDef {
  const ComponentDef(this.name, this.description, this.props);
  final String name;
  final String description;
  final List<PropDef> props;
}

class OpenUIError {
  const OpenUIError(this.code, this.message, {this.warning = false});
  final String code;
  final String message;
  final bool warning;
  @override
  String toString() => '$code: $message';
}

class ActionValue {
  const ActionValue(this.name, this.args);
  final String name; // ToAssistant, OpenUrl, Set, Reset, Run, or custom name
  final List<Object?> args;
}

/// Sentinel for a Query whose data has not arrived yet and which has no
/// initial value. It propagates through field access, index access,
/// operators and built-in functions, and makes the component that
/// directly depends on it render as a skeleton (see `__Skeleton`).
class QueryLoading {
  const QueryLoading();
}

const queryLoading = QueryLoading();

/// A Query whose tool call failed. It is a [QueryLoading] so it
/// propagates through field access, operators and functions exactly
/// like a still-loading value, but it carries the tool name so the
/// component that directly depends on it can render as a Query-error
/// node (`__QueryError`) instead of a skeleton.
class QueryFailed extends QueryLoading {
  const QueryFailed(this.tool);
  final String tool;
}

/// Find the first failed Query inside a value (deep, through lists
/// and maps), or null when the value is merely still loading.
QueryFailed? _findFailed(Object? value) {
  if (value is QueryFailed) return value;
  if (value is List) {
    for (final e in value) {
      final found = _findFailed(e);
      if (found != null) return found;
    }
  }
  if (value is Map) {
    for (final e in value.values) {
      final found = _findFailed(e);
      if (found != null) return found;
    }
  }
  return null;
}

/// Preserve a failure through a propagation site: a failed value
/// stays failed (so its tool survives), a merely loading value stays
/// the plain loading sentinel.
Object? _preserveLoading(Object? value) => _findFailed(value) ?? queryLoading;

bool isQueryLoading(Object? value) {
  if (value is QueryLoading) return true;
  if (value is List) return value.any(isQueryLoading);
  if (value is Map) return value.values.any(isQueryLoading);
  return false;
}

/// A Query statement the renderer should run through the host's tool
/// provider: `name = Query("tool", {params}, initial?)`.
/// `initial` is the value to render while loading, when given.
class QueryRequest {
  const QueryRequest({required this.statementName, required this.tool, required this.params, this.initial, this.hasInitial = false});
  final String statementName;
  final String tool;
  final Map<String, Object?> params;
  final Object? initial;
  final bool hasInitial;
}

/// A Mutation statement: `name = Mutation("tool", {params})`.
/// It is not a UI value; it is run by `@Run(name)`.
class MutationRequest {
  const MutationRequest({required this.statementName, required this.tool, required this.params});
  final String statementName;
  final String tool;
  final Map<String, Object?> params;
}

class ElementNode {
  const ElementNode(this.component, this.props, this.statementId);
  final String component;
  final Map<String, Object?> props;
  final String statementId;
  List<ElementNode> nodesOf(String prop) {
    final v = props[prop];
    if (v is ElementNode) return [v];
    if (v is List) return _flattenNodes(v);
    return const [];
  }

  static List<ElementNode> _flattenNodes(List list) {
    final out = <ElementNode>[];
    for (final e in list) {
      if (e is ElementNode) {
        out.add(e);
      } else if (e is QueryFailed) {
        out.add(ElementNode('__QueryError', {'tool': e.tool}, ''));
      } else if (e is QueryLoading) {
        out.add(const ElementNode('__Skeleton', {}, ''));
      } else if (e is List) {
        out.addAll(_flattenNodes(e));
      }
    }
    return out;
  }

  String stringOf(String prop, [String fallback = '']) {
    final v = props[prop];
    return v is String ? v : fallback;
  }

  double numOf(String prop, [double fallback = 0]) {
    final v = props[prop];
    return v is num ? v.toDouble() : fallback;
  }
}

class ParseResult {
  const ParseResult({required this.root, required this.errors, required this.unresolved, this.queries = const [], this.mutations = const []});
  final ElementNode? root;
  final List<OpenUIError> errors;
  final List<String> unresolved;
  final List<QueryRequest> queries;
  final List<MutationRequest> mutations;
  bool get hasRoot => root != null;
}

// ---------------- AST ----------------

abstract class Expr {}

class LiteralExpr extends Expr {
  LiteralExpr(this.value);
  final Object? value;
}

class RefExpr extends Expr {
  RefExpr(this.name);
  final String name;
}

class VarExpr extends Expr {
  VarExpr(this.name);
  final String name;
}

class FieldAccessExpr extends Expr {
  FieldAccessExpr(this.base, this.field);
  final Expr base;
  final String field;
}

class IndexExpr extends Expr {
  IndexExpr(this.base, this.index);
  final Expr base;
  final Expr index;
}

class ListExpr extends Expr {
  ListExpr(this.items);
  final List<Expr> items;
}

class ObjectExpr extends Expr {
  ObjectExpr(this.entries);
  final List<MapEntry<String, Expr>> entries;
}

class CallExpr extends Expr {
  CallExpr(this.name, this.args);
  final String name;
  final List<Expr> args;
}

class AtCallExpr extends Expr {
  AtCallExpr(this.name, this.args);
  final String name;
  final List<Expr> args;
}

class ActionListExpr extends Expr {
  ActionListExpr(this.items);
  final List<Expr> items;
}

class TernaryExpr extends Expr {
  TernaryExpr(this.cond, this.thenExpr, this.elseExpr);
  final Expr cond, thenExpr, elseExpr;
}

class BinaryExpr extends Expr {
  BinaryExpr(this.op, this.left, this.right);
  final String op;
  final Expr left, right;
}

class UnaryExpr extends Expr {
  UnaryExpr(this.op, this.expr);
  final String op;
  final Expr expr;
}

class QueryExpr extends Expr {
  QueryExpr(this.args, {this.isMutation = false});
  final List<Expr> args;
  final bool isMutation;
}

// ---------------- Tokenizer ----------------

class _Token {
  _Token(this.kind, this.text, this.value);
  final String kind; // ident, number, string, punct, eof
  final String text;
  final Object? value;
}

List<_Token> _tokenize(String src) {
  final out = <_Token>[];
  var i = 0;
  while (i < src.length) {
    final c = src[i];
    if (c == ' ' || c == '\t' || c == '\r') {
      i++;
      continue;
    }
    if (c == '"' || c == "'") {
      final quote = c;
      final buf = StringBuffer();
      i++;
      var closed = false;
      while (i < src.length) {
        final ch = src[i];
        if (ch == '\\' && i + 1 < src.length) {
          final n = src[i + 1];
          buf.write(switch (n) {
            'n' => '\n',
            't' => '\t',
            'r' => '\r',
            _ => n,
          });
          i += 2;
          continue;
        }
        if (ch == quote) {
          closed = true;
          i++;
          break;
        }
        buf.write(ch);
        i++;
      }
      if (!closed) throw const FormatException('unterminated string');
      out.add(_Token('string', buf.toString(), buf.toString()));
      continue;
    }
    if (c == r'$' && i + 1 < src.length && RegExp(r'[A-Za-z_]').hasMatch(src[i + 1])) {
      var j = i + 1;
      while (j < src.length && RegExp(r'[A-Za-z0-9_]').hasMatch(src[j])) {
        j++;
      }
      out.add(_Token('ident', src.substring(i, j), null));
      i = j;
      continue;
    }
    if (RegExp(r'[A-Za-z_]').hasMatch(c)) {
      var j = i;
      while (j < src.length && RegExp(r'[A-Za-z0-9_]').hasMatch(src[j])) {
        j++;
      }
      out.add(_Token('ident', src.substring(i, j), null));
      i = j;
      continue;
    }
    if (RegExp(r'[0-9]').hasMatch(c) || (c == '-' && i + 1 < src.length && RegExp(r'[0-9]').hasMatch(src[i + 1]) && out.isEmpty)) {
      // Negative literals are handled by the unary parser in general; this
      // branch only covers a leading negative number for simplicity.
      var j = i;
      if (src[j] == '-') j++;
      var dot = false;
      while (j < src.length && (RegExp(r'[0-9]').hasMatch(src[j]) || (src[j] == '.' && !dot))) {
        if (src[j] == '.') dot = true;
        j++;
      }
      final text = src.substring(i, j);
      out.add(_Token('number', text, num.tryParse(text) ?? 0));
      i = j;
      continue;
    }
    if (RegExp(r'[0-9]').hasMatch(c)) {
      var j = i;
      var dot = false;
      while (j < src.length && (RegExp(r'[0-9]').hasMatch(src[j]) || (src[j] == '.' && !dot))) {
        if (src[j] == '.') dot = true;
        j++;
      }
      final text = src.substring(i, j);
      out.add(_Token('number', text, num.tryParse(text) ?? 0));
      i = j;
      continue;
    }
    const two = ['==', '!=', '<=', '>=', '&&', '||'];
    if (i + 1 < src.length && two.contains(src.substring(i, i + 2))) {
      out.add(_Token('punct', src.substring(i, i + 2), null));
      i += 2;
      continue;
    }
    out.add(_Token('punct', c, null));
    i++;
  }
  out.add(_Token('eof', '', null));
  return out;
}

// ---------------- Expression parser ----------------

class _ExprParser {
  _ExprParser(this.tokens);
  final List<_Token> tokens;
  var pos = 0;
  _Token get cur => tokens[pos];
  _Token next() => tokens[pos++];
  bool eat(String text) {
    if (cur.text == text) {
      pos++;
      return true;
    }
    return false;
  }

  void expect(String text) {
    if (!eat(text)) throw FormatException('expected $text, got ${cur.text}');
  }

  Expr parse() {
    final e = parseTernary();
    if (cur.kind != 'eof') throw FormatException('trailing tokens: ${cur.text}');
    return e;
  }

  Expr parseTernary() {
    var e = parseOr();
    if (eat('?')) {
      final thenE = parseTernary();
      expect(':');
      final elseE = parseTernary();
      return TernaryExpr(e, thenE, elseE);
    }
    return e;
  }

  Expr _binary(Expr Function() sub, List<String> ops) {
    var e = sub();
    while (ops.contains(cur.text)) {
      final op = next().text;
      final r = sub();
      e = BinaryExpr(op, e, r);
    }
    return e;
  }

  Expr parseOr() => _binary(parseAnd, ['||']);
  Expr parseAnd() => _binary(parseEq, ['&&']);
  Expr parseEq() => _binary(parseCmp, ['==', '!=']);
  Expr parseCmp() => _binary(parseAdd, ['<', '<=', '>', '>=']);
  Expr parseAdd() => _binary(parseMul, ['+', '-']);
  Expr parseMul() => _binary(parseUnary, ['*', '/', '%']);

  Expr parseUnary() {
    if (cur.text == '!' || cur.text == '-') {
      final op = next().text;
      return UnaryExpr(op, parseUnary());
    }
    var e = parsePrimary();
    // Field access and index access: data.rows, rows[0], t.priority.
    // Number literals already consume their decimal point in the
    // tokenizer, so a '.' here is an access, not a decimal point.
    while (cur.text == '.' || cur.text == '[') {
      if (cur.text == '.') {
        next();
        final field = next();
        if (field.kind != 'ident') throw FormatException('expected field name after .');
        e = FieldAccessExpr(e, field.text);
      } else {
        next();
        final index = parseTernary();
        expect(']');
        e = IndexExpr(e, index);
      }
    }
    return e;
  }

  Expr parsePrimary() {
    final t = cur;
    if (t.kind == 'string') {
      next();
      return LiteralExpr(t.value);
    }
    if (t.kind == 'number') {
      next();
      return LiteralExpr(t.value);
    }
    if (t.text == '(') {
      next();
      final e = parseTernary();
      expect(')');
      return e;
    }
    if (t.text == '[') {
      next();
      final items = <Expr>[];
      if (!eat(']')) {
        while (true) {
          items.add(parseTernary());
          if (eat(',')) continue;
          expect(']');
          break;
        }
      }
      return ListExpr(items);
    }
    if (t.text == '{') {
      next();
      final entries = <MapEntry<String, Expr>>[];
      if (!eat('}')) {
        while (true) {
          final k = next();
          if (k.kind != 'ident' && k.kind != 'string') {
            throw FormatException('expected object key');
          }
          expect(':');
          entries.add(MapEntry(k.text, parseTernary()));
          if (eat(',')) continue;
          expect('}');
          break;
        }
      }
      return ObjectExpr(entries);
    }
    if (t.text == '@') {
      next();
      final name = next();
      if (name.kind != 'ident') throw FormatException('expected name after @');
      expect('(');
      final args = _args();
      return AtCallExpr(name.text, args);
    }
    if (t.kind == 'ident') {
      next();
      final name = t.text;
      if (name.startsWith(r'$')) return VarExpr(name.substring(1));
      if (name == 'true') return LiteralExpr(true);
      if (name == 'false') return LiteralExpr(false);
      if (name == 'null') return LiteralExpr(null);
      if (name == 'Action' && cur.text == '(') {
        next();
        expect('[');
        final items = <Expr>[];
        if (!eat(']')) {
          while (true) {
            items.add(parseTernary());
            if (eat(',')) continue;
            expect(']');
            break;
          }
        }
        expect(')');
        return ActionListExpr(items);
      }
      if (name == 'Query' || name == 'Mutation') {
        expect('(');
        final args = _args();
        return QueryExpr(args, isMutation: name == 'Mutation');
      }
      if (cur.text == '(') {
        next();
        final args = _args();
        return CallExpr(name, args);
      }
      return RefExpr(name);
    }
    throw FormatException('unexpected token ${t.text}');
  }

  List<Expr> _args() {
    final args = <Expr>[];
    if (eat(')')) return args;
    while (true) {
      args.add(parseTernary());
      if (eat(',')) continue;
      expect(')');
      return args;
    }
  }
}

// ---------------- Library ----------------

/// A custom function, mirroring the official `defineFunction` shape:
/// name, description, params in positional order, optional returns type,
/// and a pure synchronous implementation that receives one object keyed
/// by the param names, with defaults applied. An optional param with no
/// default is left out of the object.
class FunctionDef {
  const FunctionDef({
    required this.name,
    required this.description,
    required this.params,
    this.returns,
    required this.fn,
  });
  final String name;
  final String description;
  final List<PropDef> params;
  final PropType? returns;
  final Object? Function(Map<String, Object?> args) fn;
}

FunctionDef defineFunction({
  required String name,
  required String description,
  required List<PropDef> params,
  PropType? returns,
  required Object? Function(Map<String, Object?> args) fn,
}) =>
    FunctionDef(name: name, description: description, params: params, returns: returns, fn: fn);

/// A custom action declaration, mirroring the official custom-action
/// shape: name, description, params in positional order. Declaring an
/// action makes the evaluator validate `@Name(...)` calls against
/// these params; an invalid call evaluates to null with a
/// `runtime-error` instead of passing through unchecked. Undeclared
/// action names still pass through as before, for hosts that dispatch
/// actions they do not want to declare.
class ActionDef {
  const ActionDef(this.name, this.description, this.params);
  final String name;
  final String description;
  final List<PropDef> params;
}

const builtinActionNames = {'ToAssistant', 'OpenUrl', 'Set', 'Reset', 'Run'};

const builtinFunctionNames = {
  'Count',
  'Sum',
  'Avg',
  'Min',
  'Max',
  'First',
  'Last',
  'Filter',
  'Sort',
  'Round',
  'Abs',
  'Floor',
  'Ceil',
  'Each',
};

class OpenUILibrary {
  OpenUILibrary({required this.components, required this.root, this.functions = const [], this.actions = const [], this.registry}) {
    // Built-ins are looked up first, so a library must not reuse their names.
    for (final f in functions) {
      if (builtinActionNames.contains(f.name) || builtinFunctionNames.contains(f.name)) {
        throw ArgumentError('function ${f.name} reuses a built-in name');
      }
    }
    final seen = <String>{};
    for (final f in functions) {
      if (!seen.add(f.name)) throw ArgumentError('duplicate function ${f.name}');
    }
    for (final a in actions) {
      if (builtinActionNames.contains(a.name) || builtinFunctionNames.contains(a.name)) {
        throw ArgumentError('action ${a.name} reuses a built-in name');
      }
      if (functionsByName.containsKey(a.name)) {
        throw ArgumentError('action ${a.name} reuses a function name');
      }
    }
    final seenActions = <String>{};
    for (final a in actions) {
      if (!seenActions.add(a.name)) throw ArgumentError('duplicate action ${a.name}');
    }
  }
  final List<ComponentDef> components;
  final String root;
  final List<FunctionDef> functions;
  final List<ActionDef> actions;

  /// Builders for custom components, supplied via [extend]. The
  /// renderer checks an explicit `registry` argument first, then this
  /// registry, then its built-ins. Null means no custom builders.
  final ComponentRegistry? registry;

  Map<String, ComponentDef> get byName => {for (final c in components) c.name: c};
  Map<String, FunctionDef> get functionsByName => {for (final f in functions) f.name: f};
  Map<String, ActionDef> get actionsByName => {for (final a in actions) a.name: a};

  /// Returns a new library; never mutates the receiver. A component
  /// in [components] with an existing name replaces it; a name in
  /// both [remove] and [components] is added (add wins over remove);
  /// within [components], a later entry wins. Functions and actions
  /// follow the same replace-by-name rule. Builders merge into the
  /// existing registry, new names winning per name.
  OpenUILibrary extend({
    List<ComponentDef> components = const [],
    List<String> remove = const [],
    List<FunctionDef> functions = const [],
    List<ActionDef> actions = const [],
    Map<String, OpenUIComponentBuilder> builders = const {},
  }) {
    final byName = <String, ComponentDef>{for (final c in this.components) c.name: c};
    final addedNames = {for (final c in components) c.name};
    byName.removeWhere((name, _) => remove.contains(name) && !addedNames.contains(name));
    for (final c in components) {
      byName[c.name] = c;
    }
    final fnByName = <String, FunctionDef>{for (final f in this.functions) f.name: f};
    for (final f in functions) {
      fnByName[f.name] = f;
    }
    final actByName = <String, ActionDef>{for (final a in this.actions) a.name: a};
    for (final a in actions) {
      actByName[a.name] = a;
    }
    var nextRegistry = this.registry;
    if (builders.isNotEmpty) {
      var merged = nextRegistry ?? const ComponentRegistry();
      for (final entry in builders.entries) {
        merged = merged.withBuilder(entry.key, entry.value);
      }
      nextRegistry = merged;
    }
    return OpenUILibrary(
      components: byName.values.toList(),
      root: root,
      functions: fnByName.values.toList(),
      actions: actByName.values.toList(),
      registry: nextRegistry,
    );
  }

  String prompt({String? preamble, List<String> additionalRules = const [], List<String> examples = const [], bool includeBuiltins = true}) {
    final buf = StringBuffer();
    if (preamble != null) buf.writeln(preamble);
    buf.writeln('Available components (use exactly these names and argument order):');
    for (final c in components) {
      final props = c.props.map((p) {
        final req = p.required ? '' : '?';
        return '${p.name}$req: ${_typeName(p.type)}';
      }).join(', ');
      buf.writeln('- ${c.name}($props) — ${c.description}');
    }
    if (includeBuiltins) {
      buf.writeln('Built-in functions (call with @, e.g. @Count(items)):');
      buf.writeln('- @Count(array: list) -> number — Length of array');
      buf.writeln('- @Sum(array: list) -> number — Sum of numbers (numeric strings are converted)');
      buf.writeln('- @Avg(array: list) -> number — Average');
      buf.writeln('- @Min(array: list) -> number — Smallest value');
      buf.writeln('- @Max(array: list) -> number — Largest value');
      buf.writeln('- @First(array: list) -> any — First element');
      buf.writeln('- @Last(array: list) -> any — Last element');
      buf.writeln('- @Filter(array: list, field: string, operator: string, value: any) -> list — Keep items where field matches; operators: ==, !=, >, <, >=, <=, contains');
      buf.writeln('- @Sort(array: list, field: string, direction?: string) -> list — Sort by field; direction asc (default) or desc');
      buf.writeln('- @Round(number: number, decimals?: number) -> number — Round to N decimal places');
      buf.writeln('- @Abs(number: number) -> number — Absolute value');
      buf.writeln('- @Floor(number: number) -> number — Round down');
      buf.writeln('- @Ceil(number: number) -> number — Round up');
      buf.writeln('- @Each(array: list, variable: string, template: any) -> list — Render the template for every item, with the loop variable in scope');
    }
    if (functions.isNotEmpty) {
      buf.writeln('Custom functions (call with @):');
      for (final f in functions) {
        final params = f.params.map((p) {
          final req = p.required ? '' : '?';
          return '${p.name}$req: ${_typeName(p.type)}';
        }).join(', ');
        final ret = f.returns == null ? '' : ' -> ${_typeName(f.returns!)}';
        buf.writeln('- @${f.name}($params)$ret — ${f.description}');
      }
    }
    if (actions.isNotEmpty) {
      buf.writeln('Custom actions (call with @):');
      for (final a in actions) {
        final params = a.params.map((p) {
          final req = p.required ? '' : '?';
          return '${p.name}$req: ${_typeName(p.type)}';
        }).join(', ');
        buf.writeln('- @${a.name}($params) — ${a.description}');
      }
    }
    if (additionalRules.isNotEmpty) {
      buf.writeln('Additional rules:');
      for (final r in additionalRules) {
        buf.writeln('- $r');
      }
    }
    if (examples.isNotEmpty) {
      buf.writeln('Examples:');
      for (final e in examples) {
        buf.writeln(e);
      }
    }
    buf.writeln('Root component: $root. Output one assignment per line, e.g. root = $root([...]).');
    return buf.toString();
  }

  static String _typeName(PropType t) => switch (t) {
        PropType.string => 'string',
        PropType.number => 'number',
        PropType.boolean => 'boolean',
        PropType.list => 'list',
        PropType.node => 'component',
        PropType.nodeList => 'component[]',
        PropType.any => 'any',
        PropType.action => 'action',
        PropType.actionList => 'action[]',
      };
}

// ---------------- Evaluation ----------------

class _Statement {
  _Statement(this.name, this.expr);
  final String name;
  final Expr expr;
}

class _Evaluator {
  _Evaluator(this.library, this.statements, this.state, this.errors, this.unresolved, {this.queryData = const {}, this.failedQueries = const {}});
  final OpenUILibrary library;
  final Map<String, _Statement> statements;
  final Map<String, Object?> state;
  final List<OpenUIError> errors;
  final Set<String> unresolved;
  final Map<String, Object?> queryData;

  /// Statement names whose Query tool call failed. A failed Query
  /// with no data and no initial value evaluates to [QueryFailed]
  /// instead of the loading sentinel, so its dependent component
  /// renders a Query-error view rather than a skeleton forever.
  final Set<String> failedQueries;
  final List<QueryRequest> queries = [];
  final List<MutationRequest> mutations = [];
  final Set<String> _seenRequests = {};
  final Map<String, Object?> _memo = {};
  final Set<String> _visiting = {};
  Map<String, Object?> varDefaults = {};
  // Loop-variable scope for @Each templates (e.g. `t` in @Each(rows, "t", ...)).
  final Map<String, Object?> _scope = {};

  Object? evalStatement(String name) {
    if (_memo.containsKey(name)) return _memo[name];
    final stmt = statements[name];
    if (stmt == null) {
      unresolved.add(name);
      return null;
    }
    if (_visiting.contains(name)) return null; // cycle: render as nothing
    _visiting.add(name);
    var v = stmt.expr is QueryExpr ? _evalQuery(name, stmt.expr as QueryExpr) : evalExpr(stmt.expr, false);
    _visiting.remove(name);
    // Stamp the statement name onto its node, so the renderer can
    // build per-statement keys (Modal dialog guard, EditableTable
    // cell keys). Inline (non-statement) nodes keep ''.
    if (v is ElementNode && v.statementId.isEmpty) {
      v = ElementNode(v.component, v.props, name);
    }
    _memo[name] = v;
    return v;
  }

  Object? _evalQuery(String name, QueryExpr e) {
    if (e.args.isEmpty) return null;
    final toolValue = evalExpr(e.args[0], false);
    if (toolValue is! String) return null;
    final paramsValue = e.args.length > 1 ? evalExpr(e.args[1], false) : null;
    final params = <String, Object?>{};
    if (paramsValue is Map) {
      for (final entry in paramsValue.entries) {
        params['${entry.key}'] = entry.value;
      }
    } else if (paramsValue != null) {
      params['value'] = paramsValue;
    }
    if (e.isMutation) {
      if (_seenRequests.add('m:$name')) {
        mutations.add(MutationRequest(statementName: name, tool: toolValue, params: params));
      }
      return null;
    }
    final hasInitial = e.args.length > 2;
    final initial = hasInitial ? evalExpr(e.args[2], false) : null;
    if (_seenRequests.add('q:$name')) {
      queries.add(QueryRequest(statementName: name, tool: toolValue, params: params, initial: initial, hasInitial: hasInitial));
    }
    if (queryData.containsKey(name)) return queryData[name];
    if (hasInitial) return initial;
    if (failedQueries.contains(name)) return QueryFailed(toolValue);
    return queryLoading;
  }

  Object? evalVar(String name) {
    if (state.containsKey(name)) return state[name];
    if (varDefaults.containsKey(name)) return varDefaults[name];
    final stmt = statements['\$$name'];
    if (stmt == null) {
      unresolved.add('\$$name');
      return null;
    }
    final v = evalExpr(stmt.expr, false);
    varDefaults[name] = v;
    return v;
  }

  Object? evalExpr(Expr e, bool expectAction) {
    if (e is LiteralExpr) return e.value;
    if (e is RefExpr) {
      if (_scope.containsKey(e.name)) return _scope[e.name];
      return evalStatement(e.name);
    }
    if (e is VarExpr) return evalVar(e.name);
    if (e is FieldAccessExpr) {
      final base = evalExpr(e.base, false);
      if (isQueryLoading(base)) return _preserveLoading(base);
      if (base is Map) return base[e.field];
      return null;
    }
    if (e is IndexExpr) {
      final base = evalExpr(e.base, false);
      if (isQueryLoading(base)) return _preserveLoading(base);
      final index = evalExpr(e.index, false);
      if (isQueryLoading(index)) return _preserveLoading(index);
      if (base is List && index is int) {
        return index >= 0 && index < base.length ? base[index] : null;
      }
      if (base is Map) return base[index];
      return null;
    }
    if (e is ListExpr) {
      return [for (final i in e.items) evalExpr(i, false)];
    }
    if (e is ObjectExpr) {
      return {for (final en in e.entries) en.key: evalExpr(en.value, false)};
    }
    if (e is TernaryExpr) {
      final cond = evalExpr(e.cond, false);
      if (isQueryLoading(cond)) return _preserveLoading(cond);
      return evalExpr(cond == true ? e.thenExpr : e.elseExpr, expectAction);
    }
    if (e is UnaryExpr) {
      final v = evalExpr(e.expr, false);
      if (isQueryLoading(v)) return _preserveLoading(v);
      if (e.op == '!') return v != true;
      if (e.op == '-' && v is num) return -v;
      return null;
    }
    if (e is BinaryExpr) {
      final l = evalExpr(e.left, false);
      final r = evalExpr(e.right, false);
      if (isQueryLoading(l) || isQueryLoading(r)) return _findFailed(l) ?? _findFailed(r) ?? queryLoading;
      return switch (e.op) {
        '+' => (l is String || r is String) ? '${_str(l)}${_str(r)}' : (l is num && r is num ? l + r : null),
        '-' => l is num && r is num ? l - r : null,
        '*' => l is num && r is num ? l * r : null,
        '/' => l is num && r is num && r != 0 ? l / r : null,
        '%' => l is num && r is num && r != 0 ? l % r : null,
        '==' => l == r,
        '!=' => l != r,
        '<' => l is num && r is num ? l < r : (l is String && r is String ? l.compareTo(r) < 0 : false),
        '<=' => l is num && r is num ? l <= r : false,
        '>' => l is num && r is num ? l > r : false,
        '>=' => l is num && r is num ? l >= r : false,
        '&&' => l == true && r == true,
        '||' => l == true || r == true,
        _ => null,
      };
    }
    if (e is QueryExpr) {
      // Query/Mutation used inline (not as its own statement) evaluates
      // to nothing, per the specification's `inline-reserved` rule.
      errors.add(const OpenUIError('inline-reserved', 'Query/Mutation used inline'));
      return null;
    }
    if (e is ActionListExpr) {
      return [for (final i in e.items) evalExpr(i, true)];
    }
    if (e is AtCallExpr) return _evalAt(e, expectAction);
    if (e is CallExpr) return _evalComponent(e);
    return null;
  }

  String _str(Object? v) => v == null ? '' : '$v';

  Object? _evalAt(AtCallExpr e, bool expectAction) {
    if (builtinActionNames.contains(e.name)) {
      if (e.name == 'Set') {
        if (e.args.isEmpty || e.args.first is! VarExpr) return null;
        final varName = (e.args.first as VarExpr).name;
        final value = e.args.length > 1 ? evalExpr(e.args[1], false) : null;
        return ActionValue('Set', [varName, value]);
      }
      if (e.name == 'Reset') {
        final names = <Object?>[];
        for (final a in e.args) {
          if (a is VarExpr) names.add(a.name);
        }
        return ActionValue('Reset', names);
      }
      if (e.name == 'Run') {
        if (e.args.isEmpty || e.args.first is! RefExpr) return null;
        final refName = (e.args.first as RefExpr).name;
        // Evaluating a Query/Mutation statement registers its request,
        // so a Mutation is collected even though @Run only names it.
        final stmt = statements[refName];
        if (stmt != null && stmt.expr is QueryExpr) evalStatement(refName);
        return ActionValue('Run', [refName]);
      }
      final args = [for (final a in e.args) evalExpr(a, false)];
      return ActionValue(e.name, args);
    }
    if (builtinFunctionNames.contains(e.name)) return _evalBuiltin(e);
    final def = library.functionsByName[e.name];
    if (def != null) return _evalCustomFunction(def, e);
    if (expectAction) {
      final actionDef = library.actionsByName[e.name];
      if (actionDef != null) return _evalCustomAction(actionDef, e);
      final args = [for (final a in e.args) evalExpr(a, false)];
      return ActionValue(e.name, args);
    }
    errors.add(OpenUIError('unknown-function', 'unknown function ${e.name}'));
    return null;
  }

  // Custom actions: unlike custom functions, every failure is a
  // `runtime-error` and the whole action is a no-op (null), per the
  // brief. Missing required, null required, wrong type and excess
  // args all fail; a QueryLoading argument propagates as a skeleton
  // instead of failing. Undeclared action names never reach here.
  Object? _evalCustomAction(ActionDef def, AtCallExpr e) {
    if (e.args.length > def.params.length) {
      errors.add(OpenUIError('runtime-error', 'too many args for @${def.name}'));
      return null;
    }
    final args = <Object?>[];
    var failed = false;
    for (var i = 0; i < def.params.length; i++) {
      final param = def.params[i];
      if (i >= e.args.length) {
        if (param.required) {
          errors.add(OpenUIError('runtime-error', 'missing required param ${param.name} for @${def.name}'));
          failed = true;
        } else if (param.defaultValue != null) {
          args.add(param.defaultValue);
        }
        continue;
      }
      final value = evalExpr(e.args[i], false);
      if (isQueryLoading(value)) return _preserveLoading(value);
      if (value == null) {
        if (param.required) {
          errors.add(OpenUIError('runtime-error', 'null required param ${param.name} for @${def.name}'));
          failed = true;
        } else if (param.defaultValue != null) {
          args.add(param.defaultValue);
        } else {
          args.add(null);
        }
        continue;
      }
      if (!_typeOk(param.type, value)) {
        errors.add(OpenUIError('runtime-error', 'wrong type for ${param.name} for @${def.name}'));
        failed = true;
        continue;
      }
      args.add(value);
    }
    if (failed) return null;
    return ActionValue(def.name, args);
  }

  // Custom functions: same checks as component props (Functions doc).
  // Literal vs runtime matters: a literal with the wrong type is
  // `type-mismatch`; a runtime value with the wrong type is `runtime-error`.
  // A required argument that is null at runtime (unset $variable, query
  // not yet returned) makes the call null with no error. A null in place
  // of an optional argument, or a missing optional argument, takes the
  // default; an optional argument with no default is left out.
  Object? _evalCustomFunction(FunctionDef def, AtCallExpr e) {
    if (e.args.length > def.params.length) {
      errors.add(OpenUIError('excess-args', 'too many args for @${def.name}'));
    }
    final args = <String, Object?>{};
    var failed = false;
    for (var i = 0; i < def.params.length; i++) {
      final param = def.params[i];
      if (i >= e.args.length) {
        if (param.required) {
          if (param.defaultValue != null) {
            args[param.name] = param.defaultValue;
          } else {
            errors.add(OpenUIError('missing-required', 'missing required param ${param.name} for @${def.name}'));
            failed = true;
          }
        } else if (param.defaultValue != null) {
          args[param.name] = param.defaultValue;
        }
        continue;
      }
      final raw = e.args[i];
      final value = evalExpr(raw, false);
      if (isQueryLoading(value)) return _preserveLoading(value);
      if (value == null) {
        if (raw is LiteralExpr) {
          if (param.required) {
            errors.add(OpenUIError('null-required', 'null required param ${param.name} for @${def.name}'));
            failed = true;
          } else if (param.defaultValue != null) {
            args[param.name] = param.defaultValue;
          }
        } else {
          // Runtime null: no error, but a required param still fails the call.
          if (param.required) {
            failed = true;
          } else if (param.defaultValue != null) {
            args[param.name] = param.defaultValue;
          }
        }
        continue;
      }
      if (!_typeOk(param.type, value)) {
        final isLiteral = raw is LiteralExpr || raw is ListExpr || raw is ObjectExpr;
        if (param.required) {
          errors.add(OpenUIError(isLiteral ? 'type-mismatch' : 'runtime-error', 'wrong type for ${param.name} for @${def.name}'));
          failed = true;
        } else {
          errors.add(OpenUIError(isLiteral ? 'type-mismatch' : 'runtime-error', 'wrong type for ${param.name} for @${def.name}'));
          if (param.defaultValue != null) args[param.name] = param.defaultValue;
        }
        continue;
      }
      args[param.name] = value;
    }
    if (failed) return null;
    Object? result;
    try {
      result = def.fn(args);
    } catch (err) {
      errors.add(OpenUIError('runtime-error', '@${def.name} threw: $err'));
      return null;
    }
    if (def.returns != null && result != null && !_typeOk(def.returns!, result)) {
      errors.add(OpenUIError('runtime-error', '@${def.name} result does not match returns'));
      return null;
    }
    return result;
  }

  // Built-ins convert their arguments instead of validating them.
  Object? _evalBuiltin(AtCallExpr e) {
    if (e.name == 'Each') {
      if (e.args.length < 3) return null;
      final array = evalExpr(e.args[0], false);
      if (isQueryLoading(array)) return _preserveLoading(array);
      final varName = evalExpr(e.args[1], false);
      if (array is! List || varName is! String) return null;
      final template = e.args[2];
      final out = <Object?>[];
      final hadOld = _scope.containsKey(varName);
      final old = _scope[varName];
      for (final item in array) {
        _scope[varName] = item;
        final v = evalExpr(template, false);
        if (v != null) out.add(v);
      }
      if (hadOld) {
        _scope[varName] = old;
      } else {
        _scope.remove(varName);
      }
      return out;
    }
    final args = [for (final a in e.args) evalExpr(a, false)];
    if (args.any(isQueryLoading)) return _preserveLoading(args);
    Object? first = args.isEmpty ? null : args[0];
    List listOf(Object? v) => v is List ? v : const [];
    double? toNum(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    List<double> numsOf(List list) {
      final out = <double>[];
      for (final v in list) {
        final n = toNum(v);
        if (n != null) out.add(n);
      }
      return out;
    }

    switch (e.name) {
      case 'Count':
        return listOf(first).length;
      case 'Sum':
        return numsOf(listOf(first)).fold<double>(0, (a, b) => a + b);
      case 'Avg':
        final nums = numsOf(listOf(first));
        return nums.isEmpty ? null : nums.reduce((a, b) => a + b) / nums.length;
      case 'Min':
        final nums = numsOf(listOf(first));
        return nums.isEmpty ? null : nums.reduce((a, b) => a < b ? a : b);
      case 'Max':
        final nums = numsOf(listOf(first));
        return nums.isEmpty ? null : nums.reduce((a, b) => a > b ? a : b);
      case 'First':
        final list = listOf(first);
        return list.isEmpty ? null : list.first;
      case 'Last':
        final list = listOf(first);
        return list.isEmpty ? null : list.last;
      case 'Filter':
        if (args.length < 4) return const [];
        final field = args[1] is String ? args[1] as String : '';
        final op = args[2] is String ? args[2] as String : '==';
        final wanted = args[3];
        bool matches(Object? item) {
          final fv = item is Map ? item[field] : null;
          return switch (op) {
            '==' => fv == wanted,
            '!=' => fv != wanted,
            '>' => _compare(fv, wanted) > 0,
            '<' => _compare(fv, wanted) < 0,
            '>=' => _compare(fv, wanted) >= 0,
            '<=' => _compare(fv, wanted) <= 0,
            'contains' => fv is String && wanted is String
                ? fv.contains(wanted)
                : fv is List
                    ? fv.contains(wanted)
                    : false,
            _ => false,
          };
        }

        return listOf(first).where(matches).toList();
      case 'Sort':
        if (args.length < 2) return listOf(first);
        final field = args[1] is String ? args[1] as String : '';
        final desc = args.length > 2 && args[2] == 'desc';
        final list = List.of(listOf(first));
        int cmp(Object? a, Object? b) {
          final fa = a is Map ? a[field] : a;
          final fb = b is Map ? b[field] : b;
          if (fa == null && fb == null) return 0;
          if (fa == null) return 1;
          if (fb == null) return -1;
          return _compare(fa, fb);
        }

        list.sort((a, b) => desc ? -cmp(a, b) : cmp(a, b));
        return list;
      case 'Round':
        final n = toNum(first);
        if (n == null) return null;
        final decimals = args.length > 1 ? (toNum(args[1])?.round() ?? 0) : 0;
        final factor = _pow10(decimals);
        return (n * factor).round() / factor;
      case 'Abs':
        final n = toNum(first);
        return n == null ? null : n.abs();
      case 'Floor':
        final n = toNum(first);
        return n == null ? null : n.floorToDouble();
      case 'Ceil':
        final n = toNum(first);
        return n == null ? null : n.ceilToDouble();
      default:
        return null;
    }
  }

  int _compare(Object? a, Object? b) {
    if (a is num && b is num) return a.compareTo(b);
    if (a is String && b is String) return a.compareTo(b);
    return '$a'.compareTo('$b');
  }

  double _pow10(int n) {
    var r = 1.0;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  Object? _evalComponent(CallExpr e) {
    final def = library.byName[e.name];
    if (def == null) {
      errors.add(OpenUIError('unknown-component', 'unknown component ${e.name}'));
      return null;
    }
    if (e.args.length > def.props.length) {
      errors.add(OpenUIError('excess-args', 'too many args for ${e.name}'));
    }
    final props = <String, Object?>{};
    var dropped = false;
    for (var i = 0; i < def.props.length; i++) {
      final prop = def.props[i];
      Object? value;
      var present = false;
      if (i < e.args.length) {
        present = true;
        final isActionProp = prop.type == PropType.action || prop.type == PropType.actionList;
        value = evalExpr(e.args[i], isActionProp);
        if (prop.type == PropType.actionList && value is ActionValue) value = [value];
        if (isQueryLoading(value)) {
          final failed = _findFailed(value);
          if (prop.type == PropType.nodeList) {
            // A loading child list becomes a skeleton placeholder;
            // a failed one becomes an error placeholder; a list
            // containing loading elements is handled by
            // _flattenNodes below, which inserts skeletons (or
            // error nodes for failed elements).
            if (failed != null) {
              props[prop.name] = [ElementNode('__QueryError', {'tool': failed.tool}, '')];
              continue;
            }
            if (value is QueryLoading) {
              props[prop.name] = [const ElementNode('__Skeleton', {}, '')];
              continue;
            }
          } else {
            if (failed != null) return ElementNode('__QueryError', {'tool': failed.tool}, '');
            return const ElementNode('__Skeleton', {}, '');
          }
        }
      }
      if (value == null && present) {
        if (prop.required && prop.defaultValue == null) {
          errors.add(OpenUIError('null-required', 'null required prop ${prop.name} on ${e.name}'));
          dropped = true;
          continue;
        }
        value = prop.defaultValue;
      }
      if (!present) {
        if (prop.required && prop.defaultValue == null) {
          errors.add(OpenUIError('missing-required', 'missing required prop ${prop.name} on ${e.name}'));
          dropped = true;
          continue;
        }
        value = prop.defaultValue;
      }
      if (value != null && !_typeOk(prop.type, value)) {
        errors.add(OpenUIError('type-mismatch', 'wrong type for ${prop.name} on ${e.name}'));
        if (prop.defaultValue != null) {
          value = prop.defaultValue;
        } else if (!prop.required) {
          continue;
        } else {
          dropped = true;
          continue;
        }
      }
      if (prop.type == PropType.nodeList && value is ElementNode) value = [value];
      if (prop.type == PropType.nodeList && value is List) {
        // Flatten one or more levels, so @Each results used as
        // Stack([tags]) keep their nodes instead of being dropped.
        value = ElementNode('', {'children': value}, '').nodesOf('children');
      }
      props[prop.name] = value;
    }
    if (dropped) return null;
    return ElementNode(e.name, props, '');
  }

  bool _typeOk(PropType t, Object? v) => switch (t) {
        PropType.string => v is String,
        PropType.number => v is num,
        PropType.boolean => v is bool,
        PropType.list => v is List,
        PropType.node => v is ElementNode,
        PropType.nodeList => v is List,
        PropType.any => true,
        PropType.action => v is ActionValue || v is List,
        PropType.actionList => v is List,
      };
}

ParseResult parseOpenUI(String text, OpenUILibrary library, {Map<String, Object?> state = const {}, Map<String, Object?> queryData = const {}, bool streaming = false, Set<String> failedQueries = const {}}) {
  final errors = <OpenUIError>[];
  final unresolved = <String>{};
  // Stored-message markers: skip marker lines; JSON context after
  // ]]>openui:context is host data, not OpenUI Lang.
  var inContext = false;
  final lines = <String>[];
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.startsWith(']]>openui:')) {
      inContext = line.startsWith(']]>openui:context');
      continue;
    }
    if (inContext) {
      if (line.startsWith('}')) inContext = false;
      continue;
    }
    if (line.isEmpty) continue;
    lines.add(line);
  }
  final statements = <String, _Statement>{};
  var order = <String>[];
  final stmtRe = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*|\$[A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)\s*(.+)$');
  for (final line in lines) {
    final m = stmtRe.firstMatch(line);
    if (m == null) {
      errors.add(OpenUIError('parse-failed', 'not a statement: $line'));
      continue;
    }
    final name = m.group(1)!;
    final exprText = m.group(2)!;
    try {
      final expr = _ExprParser(_tokenize(exprText)).parse();
      if (!statements.containsKey(name)) order.add(name);
      statements[name] = _Statement(name, expr); // last wins
    } catch (_) {
      errors.add(OpenUIError('parse-failed', 'cannot parse statement $name'));
    }
  }
  final evaluator = _Evaluator(library, statements, Map.of(state), errors, unresolved, queryData: queryData, failedQueries: failedQueries);
  // Evaluate $variable defaults eagerly so Reset can restore them.
  for (final name in order) {
    if (name.startsWith(r'$')) evaluator.evalVar(name.substring(1));
  }
  ElementNode? root;
  var usedFallback = false;
  if (statements.containsKey('root')) {
    final v = evaluator.evalStatement('root');
    if (v is ElementNode) root = v;
  } else {
    // Fallback: first statement calling the library root component.
    for (final name in order) {
      final stmt = statements[name]!;
      if (stmt.expr is CallExpr && (stmt.expr as CallExpr).name == library.root) {
        final v = evaluator.evalStatement(name);
        if (v is ElementNode) {
          root = v;
          usedFallback = true;
        }
        break;
      }
    }
    if (root == null) {
      errors.add(const OpenUIError('no-root', 'no root statement', warning: true));
    } else if (usedFallback) {
      errors.add(const OpenUIError('no-root', 'no root statement, using fallback', warning: true));
    }
  }
  if (!streaming) {
    errors.removeWhere((e) => e.warning);
  }
  // After a complete parse, unresolved refs are real; during streaming
  // they are expected (forward references not yet arrived).
  final unresolvedList = streaming ? <String>[] : unresolved.toList();
  return ParseResult(root: root, errors: errors, unresolved: unresolvedList, queries: evaluator.queries, mutations: evaluator.mutations);
}

/// Autocloser: make partial (mid-stream) text syntactically valid by
/// appending the minimal closing quote and brackets. Brackets inside
/// strings do not count, a trailing comma is dropped, and a trailing
/// backslash inside an unfinished string is dropped before closing it.
String autoCloseOpenUI(String text) {
  var s = text.trimRight();
  while (s.endsWith(',')) {
    s = s.substring(0, s.length - 1).trimRight();
  }
  final stack = <String>[];
  String? quote;
  var escaped = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (c == '\\') {
        escaped = true;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == '"' || c == "'") {
      quote = c;
    } else if (c == '(' || c == '[' || c == '{') {
      stack.add(c);
    } else if (c == ')' || c == ']' || c == '}') {
      const pairs = {'(': ')', '[': ']', '{': '}'};
      if (stack.isNotEmpty && pairs[stack.last] == c) stack.removeLast();
    }
  }
  final buf = StringBuffer(s);
  if (quote != null) {
    if (buf.toString().endsWith('\\')) {
      // Drop the dangling escape before closing the string.
      final t = buf.toString();
      buf.clear();
      buf.write(t.substring(0, t.length - 1));
    }
    buf.write(quote);
  }
  const closers = {'(': ')', '[': ']', '{': '}'};
  for (var i = stack.length - 1; i >= 0; i--) {
    buf.write(closers[stack[i]]);
  }
  return buf.toString();
}

class StreamingParser {
  StreamingParser(this.library, {this.state = const {}, this.queryData = const {}, this.failedQueries = const {}});
  final OpenUILibrary library;
  final Map<String, Object?> state;
  final Map<String, Object?> queryData;

  /// Statement names whose Query failed (a mutable set the host
  /// updates as fetches fail and retry; read on every parse, so a
  /// failure that lands mid-stream shows as an error view).
  final Set<String> failedQueries;
  var _buffer = '';
  var _pending = '';

  /// Push the next chunk. Complete lines are parsed as-is; the pending
  /// (last, unterminated) line is parsed after autoclosing, so a
  /// half-written component already renders. Queries and mutations are
  /// taken from the complete lines only, so a half-written Query never
  /// triggers a tool call with partial parameters.
  ParseResult push(String chunk) {
    _buffer += chunk;
    final parts = _buffer.split('\n');
    _pending = parts.removeLast();
    final complete = parts.join('\n');
    final stable = parseOpenUI(complete, library, state: state, queryData: queryData, streaming: true, failedQueries: failedQueries);
    if (_pending.trim().isEmpty) return stable;
    final displayText = complete.isEmpty ? autoCloseOpenUI(_pending) : '$complete\n${autoCloseOpenUI(_pending)}';
    final display = parseOpenUI(displayText, library, state: state, queryData: queryData, streaming: true, failedQueries: failedQueries);
    return ParseResult(
      root: display.root,
      errors: display.errors,
      unresolved: display.unresolved,
      queries: stable.queries,
      mutations: stable.mutations,
    );
  }

  ParseResult finish() {
    _pending = '';
    return parseOpenUI(_buffer, library, state: state, queryData: queryData, streaming: false, failedQueries: failedQueries);
  }
}

/// A stored assistant message, split into its parts: the prose, the
/// last fenced OpenUI Lang program (last-program-wins), and the form
/// state restored from the `]]>openui:context` JSON block.
class StoredMessage {
  const StoredMessage({required this.prose, required this.result, required this.formState});
  final String prose;
  final ParseResult result;
  final Map<String, Object?> formState;
}

/// Parse a stored message. Sections are delimited by markers and
/// fenced blocks:
///
/// ```text
/// Prose text.
/// ]]>openui:content
/// More prose.
/// ```openui
/// root = Stack([TextContent("first")])
/// ```
/// ```openui
/// root = Stack([TextContent("second")])
/// ```
/// ]]>openui:context
/// {"formState": {"city": "Tokyo"}}
/// ```
///
/// Text outside fences is prose (both before and after a
/// `]]>openui:content` marker); the last fenced program wins; the
/// context JSON's `formState` map is returned separately and also
/// merged into the parse state, so `$variables` in the program
/// resolve to the restored values. With no fenced program, the
/// remaining Lang lines are parsed directly (markers and context
/// stripped, as [parseOpenUI] already does). Malformed context JSON
/// is ignored: it is host data, not a Lang error.
StoredMessage parseStoredMessage(String text, OpenUILibrary library, {Map<String, Object?> state = const {}, Map<String, Object?> queryData = const {}}) {
  final proseLines = <String>[];
  final programs = <String>[];
  final contextLines = <String>[];
  var section = 'prose';
  var inFence = false;
  final fenceLines = <String>[];
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (inFence) {
      if (line.startsWith('```')) {
        inFence = false;
        programs.add(fenceLines.join('\n'));
        fenceLines.clear();
      } else {
        fenceLines.add(raw);
      }
      continue;
    }
    if (line.startsWith('```')) {
      inFence = true;
      continue;
    }
    if (line.startsWith(']]>openui:')) {
      section = line.startsWith(']]>openui:context') ? 'context' : 'prose';
      continue;
    }
    if (section == 'context') {
      contextLines.add(raw);
    } else {
      proseLines.add(raw);
    }
  }
  if (inFence && fenceLines.isNotEmpty) programs.add(fenceLines.join('\n'));
  final formState = <String, Object?>{};
  final contextText = contextLines.join('\n').trim();
  if (contextText.isNotEmpty) {
    try {
      final decoded = jsonDecode(contextText);
      if (decoded is Map && decoded['formState'] is Map) {
        for (final entry in (decoded['formState'] as Map).entries) {
          formState['${entry.key}'] = entry.value;
        }
      }
    } catch (_) {
      // Malformed context JSON: host data, not a Lang error.
    }
  }
  final mergedState = {...state, ...formState};
  final result = programs.isNotEmpty
      ? parseOpenUI(programs.last, library, state: mergedState, queryData: queryData)
      : parseOpenUI(proseLines.join('\n'), library, state: mergedState, queryData: queryData);
  return StoredMessage(prose: proseLines.join('\n').trim(), result: result, formState: formState);
}
