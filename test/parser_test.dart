import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

void main() {
  final library = openUIMvpLibrary();

  test('forward reference renders root before children arrive', () {
    final r = parseOpenUI('''
root = Stack([header, chart])
header = CardHeader("Q1", "全部")
chart = BarChart(months, [rev])
months = ["1月", "2月"]
rev = Series("收入", [120, 145])
''', library);
    expect(r.root, isNotNull);
    expect(r.root!.component, 'Stack');
    expect(r.errors, isEmpty);
  });

  test('last definition wins', () {
    final r = parseOpenUI('''
root = TextContent("旧")
root = TextContent("新")
''', library);
    expect(r.root!.stringOf('text'), '新');
  });

  test('root fallback uses first root-component statement', () {
    final r = parseOpenUI('title = TextContent("订单")\npage = Card([title])\n', library);
    // Card is not the library root (Stack), so no fallback: no-root is a
    // warning and is removed on a complete parse.
    expect(r.root, isNull);
    expect(r.errors, isEmpty);
  });

  test('unknown component and missing required are reported, rest renders', () {
    final r = parseOpenUI('''
root = Stack([ok, bad, broken])
ok = TextContent("在")
bad = NoSuch("x")
broken = CardHeader()
''', library);
    expect(r.root, isNotNull);
    expect(r.errors.map((e) => e.code), containsAll(['unknown-component', 'missing-required']));
    final children = r.root!.nodesOf('children');
    expect(children.map((c) => c.component), ['TextContent']);
  });

  test('variable, ternary and Set action', () {
    final r = parseOpenUI(r'''
$compact = false
root = Stack([view, btn])
view = $compact ? TextContent("紧凑") : TextContent("完整")
btn = Button("保存", @Set($saved, true))
''', library);
    expect(r.root, isNotNull);
    final view = r.root!.nodesOf('children')[0];
    expect(view.stringOf('text'), '完整');
    final btn = r.root!.nodesOf('children')[1];
    final action = btn.props['action'] as ActionValue;
    expect(action.name, 'Set');
    expect(action.args, ['saved', true]);
  });

  test('streaming parser holds incomplete last line', () {
    final sp = StreamingParser(library);
    final mid = sp.push('root = Stack([header])\nheader = CardHeader("Q1"');
    // Incomplete line is not parsed yet, so header is unresolved on stream.
    expect(mid.root, isNotNull);
    final done = sp.push(', "全部")\n');
    expect(done.root, isNotNull);
    final header = done.root!.nodesOf('children').first;
    expect(header.stringOf('subtitle'), '全部');
  });

  FunctionDef percentDef() => defineFunction(
        name: 'Percent',
        description: 'Formats part / total as a percentage',
        params: const [
          PropDef('part', PropType.number, required: true),
          PropDef('total', PropType.number, defaultValue: 100),
        ],
        returns: PropType.string,
        fn: (args) {
          final part = (args['part'] as num).toDouble();
          final total = (args['total'] as num).toDouble();
          return '${(part / total * 100).toStringAsFixed(1)}%';
        },
      );

  test('custom function', () {
    final lib = openUIMvpLibrary(functions: [percentDef()]);
    final r = parseOpenUI('root = TextContent("完成率: " + @Percent(30, 120))\n', lib);
    expect(r.root!.stringOf('text'), '完成率: 25.0%');
  });

  test('custom function: default, missing, literal type error, excess args', () {
    final lib = openUIMvpLibrary(functions: [percentDef()]);
    // Default total = 100.
    expect(parseOpenUI('root = TextContent("" + @Percent(42))\n', lib).root!.stringOf('text'), '42.0%');
    // Missing required part.
    final missing = parseOpenUI('root = TextContent("" + @Percent())\n', lib);
    expect(missing.errors.map((e) => e.code), contains('missing-required'));
    // Literal wrong type for required param.
    final wrong = parseOpenUI('root = TextContent("" + @Percent("42", 120))\n', lib);
    expect(wrong.errors.map((e) => e.code), contains('type-mismatch'));
    expect(wrong.root!.stringOf('text'), '');
    // Excess args are dropped, call still runs.
    final excess = parseOpenUI('root = TextContent("" + @Percent(30, 120, 999))\n', lib);
    expect(excess.errors.map((e) => e.code), contains('excess-args'));
    expect(excess.root!.stringOf('text'), '25.0%');
    // Optional wrong type: default applies, call runs.
    final optWrong = parseOpenUI('root = TextContent("" + @Percent(30, "x"))\n', lib);
    expect(optWrong.errors.map((e) => e.code), contains('type-mismatch'));
    expect(optWrong.root!.stringOf('text'), '30.0%');
  });

  test('custom function: runtime null is silent, returns mismatch is runtime-error', () {
    final lib = openUIMvpLibrary(functions: [percentDef()]);
    // Unset $variable: required runtime null, no error, call is null.
    final runtimeNull = parseOpenUI('root = TextContent("完成率: " + @Percent(\$missing, 120))\n', lib);
    expect(runtimeNull.errors, isEmpty);
    expect(runtimeNull.root!.stringOf('text'), '完成率: ');
    // Returns mismatch.
    final badReturns = openUIMvpLibrary(functions: [
      defineFunction(
        name: 'Bad',
        description: 'returns a number but declares string',
        params: const [],
        returns: PropType.string,
        fn: (_) => 42,
      ),
    ]);
    final bad = parseOpenUI('root = TextContent("" + @Bad())\n', badReturns);
    expect(bad.errors.map((e) => e.code), contains('runtime-error'));
    // Unknown function.
    final unknown = parseOpenUI('root = TextContent("Total: " + @Total(items))\n', lib);
    expect(unknown.errors.map((e) => e.code), contains('unknown-function'));
    expect(unknown.root!.stringOf('text'), 'Total: ');
    // A custom function may not reuse a built-in name.
    expect(
      () => openUIMvpLibrary(functions: [
        defineFunction(name: 'Sum', description: 'shadow', params: const [], fn: (_) => 0),
      ]),
      throwsArgumentError,
    );
  });

  test('built-in functions: Sum converts, Filter/Count nest, Each with field access', () {
    final r = parseOpenUI('''
root = TextContent("总数: " + @Sum(sales) + ", 开放: " + @Count(@Filter(rows, "status", "==", "open")))
sales = ["1", 2]
rows = [{"status": "open"}, {"status": "closed"}, {"status": "open"}]
''', library);
    expect(r.root!.stringOf('text'), '总数: 3.0, 开放: 2');
    final each = parseOpenUI('''
root = Stack([tags])
tags = @Each(rows, "t", TextContent(t.priority))
rows = [{"priority": "高"}, {"priority": "低"}]
''', library);
    expect(each.root, isNotNull);
    expect(each.errors, isEmpty);
    expect(each.root!.nodesOf('children').map((c) => c.stringOf('text')), ['高', '低']);
    final round = parseOpenUI('root = TextContent("" + @Round(3.14159, 2))\n', library);
    expect(round.root!.stringOf('text'), '3.14');
  });

  test('function prompt lists built-ins and custom functions', () {
    final lib = openUIMvpLibrary(functions: [percentDef()]);
    expect(lib.prompt(), contains('@Count('));
    expect(lib.prompt(), contains('@Percent(part: number, total?: number) -> string'));
  });

  test('library prompt lists all 86 components', () {
    // 86 GenUI names plus 9 extra chart components added in Task 6.
    expect(library.components.length, 95);
    expect(library.prompt(), contains('Tabs('));
    expect(library.prompt(), contains('TabItem('));
    expect(library.prompt(), contains('Accordion('));
    expect(library.prompt(), contains('SnippetBlock('));
  });
}
