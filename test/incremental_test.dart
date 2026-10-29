import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

// Token-level incremental parsing: an IncrementalOpenUIParser fed a
// program chunk by chunk must produce the same result as a one-shot
// parseOpenUI of the final text, while only parsing new lines and
// re-evaluating changed statements (see stats tests).
void main() {
  final library = openUIStandardLibrary();

  String serialize(Object? v) {
    if (v == null) return 'null';
    if (v is ElementNode) {
      final keys = v.props.keys.toList()..sort();
      return '${v.component}#${v.statementId}{${keys.map((k) => '$k=${serialize(v.props[k])}').join(',')}}';
    }
    if (v is List) return '[${v.map(serialize).join(',')}]';
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      return '{${keys.map((k) => '$k=${serialize(v[k])}').join(',')}}';
    }
    if (v is ActionValue) return 'Action(${v.name},[${v.args.map(serialize).join(',')}])';
    if (v is QueryFailed) return 'QueryFailed(${v.tool})';
    if (isQueryLoading(v)) return 'queryLoading';
    return '$v';
  }

  void expectSameResult(ParseResult a, ParseResult b, String label) {
    expect(serialize(a.root), serialize(b.root), reason: '$label root');
    final errorsA = a.errors.map((e) => '${e.code}:${e.message}').toList()..sort();
    final errorsB = b.errors.map((e) => '${e.code}:${e.message}').toList()..sort();
    expect(errorsA, errorsB, reason: '$label errors');
    expect(a.unresolved.toSet(), b.unresolved.toSet(), reason: '$label unresolved');
    expect(a.queries.map((q) => '${q.statementName}:${q.tool}:${q.params}:${q.initial}').toSet(), b.queries.map((q) => '${q.statementName}:${q.tool}:${q.params}:${q.initial}').toSet(), reason: '$label queries');
    expect(a.mutations.map((m) => '${m.statementName}:${m.tool}:${m.params}').toSet(), b.mutations.map((m) => '${m.statementName}:${m.tool}:${m.params}').toSet(), reason: '$label mutations');
  }

  /// Feed [text] to a fresh incremental parser in [chunks] (each an
  /// increasing prefix length), then compare the final non-streaming
  /// result to a one-shot parse.
  void expectIncrementalEqualsFull(String text, List<int> cutPoints, {OpenUILibrary? lib, Map<String, Object?> state = const {}, Map<String, Object?> queryData = const {}, Set<String> failedQueries = const {}}) {
    final parser = IncrementalOpenUIParser(lib ?? library);
    ParseResult? last;
    for (final cut in cutPoints) {
      last = parser.parse(text.substring(0, cut), state: state, queryData: queryData, streaming: true, failedQueries: failedQueries);
    }
    last = parser.parse(text, state: state, queryData: queryData, streaming: false, failedQueries: failedQueries);
    final full = parseOpenUI(text, lib ?? library, state: state, queryData: queryData, failedQueries: failedQueries);
    expectSameResult(last, full, 'incremental vs full');
  }

  List<int> lineCuts(String text) {
    final cuts = <int>[];
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '\n') cuts.add(i + 1);
    }
    if (cuts.isEmpty || cuts.last != text.length) cuts.add(text.length);
    return cuts;
  }

  List<int> charCuts(String text) => [for (var i = 1; i <= text.length; i++) i];

  List<int> fixedCuts(String text, int size) {
    final cuts = <int>[];
    for (var i = size; i < text.length; i += size) {
      cuts.add(i);
    }
    cuts.add(text.length);
    return cuts;
  }

  const basic = '''
root = Stack([a, b, c])
a = Text("text", "hello")
b = BoldText("text", "world")
c = Tag("tag", "star")
''';

  test('basic program matches full parse under every chunking', () {
    expectIncrementalEqualsFull(basic, lineCuts(basic));
    expectIncrementalEqualsFull(basic, charCuts(basic));
    expectIncrementalEqualsFull(basic, fixedCuts(basic, 7));
  });

  const forwardAndRedefine = '''
root = Stack([a, b, later])
a = Text("text", "one")
b = Text("text", "two")
a = Text("text", "last wins")
later = Text("text", "forward ref ok")
''';

  test('forward references and last-wins redefinition match', () {
    expectIncrementalEqualsFull(forwardAndRedefine, lineCuts(forwardAndRedefine));
    expectIncrementalEqualsFull(forwardAndRedefine, charCuts(forwardAndRedefine));
  });

  const varsAndQueries = r'''
$city = "Tokyo"
$greeting = "hi " + $city
q = Query("weather", {"city": $city}, {"status": "sunny"})
m = Mutation("save", {"city": $city})
root = Stack([Text($greeting), TextContent(q.status)])
''';

  test('variables, queries and mutations match, with and without query data', () {
    expectIncrementalEqualsFull(varsAndQueries, lineCuts(varsAndQueries));
    expectIncrementalEqualsFull(varsAndQueries, fixedCuts(varsAndQueries, 5));
    expectIncrementalEqualsFull(varsAndQueries, lineCuts(varsAndQueries), queryData: {'q': {'status': 'open'}});
    expectIncrementalEqualsFull(varsAndQueries, lineCuts(varsAndQueries), failedQueries: {'q'});
  });

  test('query data arriving mid-stream updates the result', () {
    const text = '''
q = Query("weather", {"city": "Tokyo"}, {"status": "sunny"})
root = Stack([TextContent(q.status)])
''';
    final parser = IncrementalOpenUIParser(library);
    final before = parser.parse(text, streaming: false);
    expect(serialize(before.root), contains('sunny'));
    final after = parser.parse(text, queryData: {'q': {'status': 'open'}}, streaming: false);
    expect(serialize(after.root), contains('open'));
    expectSameResult(after, parseOpenUI(text, library, queryData: {'q': {'status': 'open'}}), 'query data change');
    // Line parses are reused across the data change.
    expect(parser.stats.linesParsed, 2);
  });

  test('form state change re-evaluates without re-parsing lines', () {
    const text = r'''
$city = "Tokyo"
root = Stack([Text("text", $city)])
''';
    final parser = IncrementalOpenUIParser(library);
    final before = parser.parse(text, streaming: false);
    expect(serialize(before.root), contains('Tokyo'));
    final linesBefore = parser.stats.linesParsed;
    final after = parser.parse(text, state: {'city': 'Osaka'}, streaming: false);
    expect(serialize(after.root), contains('Osaka'));
    expect(parser.stats.linesParsed, linesBefore);
    expectSameResult(after, parseOpenUI(text, library, state: {'city': 'Osaka'}), 'state change');
  });

  const errorsAndCycles = '''
root = Stack([a, b, missing, bad, cyc1])
a = UnknownComponent("x")
b = Text(42)
missing = Nope("x")
bad = Text("text", "unclosed
cyc1 = Stack([cyc2])
cyc2 = Stack([cyc1])
this is not a statement
''';

  test('errors, cycles and unparseable lines match', () {
    expectIncrementalEqualsFull(errorsAndCycles, lineCuts(errorsAndCycles));
    expectIncrementalEqualsFull(errorsAndCycles, charCuts(errorsAndCycles));
  });

  const expressions = '''
rows = [{"priority": "P0"}, {"priority": "P1"}]
tags = @Each(rows, "t", TextContent(t.priority))
cond = true ? Text("text", "yes") : Text("text", "no")
total = 2 + 3 * 4
label = "total=" + total
root = Stack([tags, cond, Text(label)])
''';

  test('expressions, Each and computed values match', () {
    expectIncrementalEqualsFull(expressions, lineCuts(expressions));
    expectIncrementalEqualsFull(expressions, fixedCuts(expressions, 11));
  });

  const contextMarkers = '''
]]>openui:context
{"formState": {"city": "Tokyo"}}
}
root = Stack([Text("text", "after")])
''';

  test('context markers and fallback roots match', () {
    expectIncrementalEqualsFull(contextMarkers, lineCuts(contextMarkers));
    expectIncrementalEqualsFull(contextMarkers, charCuts(contextMarkers));
    const fallback = '''
main = Stack([Text("text", "fallback")])
''';
    expectIncrementalEqualsFull(fallback, lineCuts(fallback));
    const noRoot = '''
a = Text("text", "no root here")
''';
    expectIncrementalEqualsFull(noRoot, lineCuts(noRoot));
    const rootNonNode = '''
root = 42
''';
    expectIncrementalEqualsFull(rootNonNode, lineCuts(rootNonNode));
  });

  test('nested standard programs match', () {
    const text = '''
root = Stack([card])
card = Card([tabs])
tabs = Tabs([TabItem("t", "标签", [TextContent("内")])])
''';
    expectIncrementalEqualsFull(text, lineCuts(text), lib: library);
    expectIncrementalEqualsFull(text, charCuts(text), lib: library);
  });

  test('StreamingParser finish matches a full parse', () {
    const text = '''
root = Stack([a, q])
a = Text("text", "hello")
q = Query("list_tools", {"x": 1}, "init")
''';
    final sp = StreamingParser(library);
    var offset = 0;
    for (final cut in fixedCuts(text, 6)) {
      sp.push(text.substring(offset, cut));
      offset = cut;
    }
    final finished = sp.finish();
    expectSameResult(finished, parseOpenUI(text, library), 'streaming finish');
  });

  test('StreamingParser intermediate pushes match stable/display parses', () {
    const text = '''
root = Stack([a, q])
a = Text("text", "hello")
q = Query("list_tools", {"x": 1}, "init")
''';
    final sp = StreamingParser(library);
    var offset = 0;
    var buffer = '';
    for (final cut in fixedCuts(text, 9)) {
      final chunk = text.substring(offset, cut);
      offset = cut;
      buffer += chunk;
      final pushed = sp.push(chunk);
      // Display result: complete lines + autoclosed pending.
      final parts = buffer.split('\n');
      final pending = parts.removeLast();
      final complete = parts.join('\n');
      final displayText = pending.trim().isEmpty ? complete : (complete.isEmpty ? autoCloseOpenUI(pending) : '$complete\n${autoCloseOpenUI(pending)}');
      final expectedDisplay = parseOpenUI(displayText, library, streaming: true);
      expect(serialize(pushed.root), serialize(expectedDisplay.root), reason: 'display root at cut $cut');
      expect(pushed.errors.map((e) => '${e.code}:${e.message}').toList()..sort(), expectedDisplay.errors.map((e) => '${e.code}:${e.message}').toList()..sort(), reason: 'display errors at cut $cut');
      final expectedStable = parseOpenUI(complete, library, streaming: true);
      expect(pushed.queries.map((q) => q.statementName).toSet(), expectedStable.queries.map((q) => q.statementName).toSet(), reason: 'stable queries at cut $cut');
    }
  });

  test('stats prove incrementality on a long program', () {
    final lines = <String>['root = Stack([${List.generate(60, (i) => 's$i').join(', ')}])'];
    for (var i = 0; i < 60; i++) {
      lines.add('s$i = Text("text", "item $i")');
    }
    final text = '${lines.join('\n')}\n';
    final parser = IncrementalOpenUIParser(library);
    for (final cut in lineCuts(text)) {
      parser.parse(text.substring(0, cut), streaming: true);
    }
    final result = parser.parse(text, streaming: false);
    expectSameResult(result, parseOpenUI(text, library), 'long program');
    expect(parser.stats.parseCalls, lineCuts(text).length + 1);
    // 61 lines parsed once each, not once per push (61 x 62).
    expect(parser.stats.linesParsed, lessThanOrEqualTo(65));
    // Each leaf once, root once per new child: far below 61 x 61.
    expect(parser.stats.freshEvaluations, lessThan(200));
    // A repeat parse with identical text costs nothing new.
    final before = parser.stats;
    parser.parse(text, streaming: false);
    expect(parser.stats.linesParsed, before.linesParsed);
    expect(parser.stats.freshEvaluations, before.freshEvaluations);
  });
}
