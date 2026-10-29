import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_lang/openui_lang.dart';

// Batch B: card-block props aligned with @openuidev/react-ui 0.18.1
// Zod schemas (docs/react-1.0-diff/react-source-props.md §2). Blocks
// share items/layout/responsive/action/gap and have no title prop;
// items take node refs instead of the old text/action/src shapes.

Future<void> _pumpCard(tester, String body) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SingleChildScrollView(
        child: OpenUIRenderer(
          library: openUIStandardLibrary(),
          response: 'root = Stack([$body])\n',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final library = openUIStandardLibrary();

  test('block defs have no title; items take node refs', () {
    for (final name in ['SnippetCardBlock', 'OverviewCardBlock', 'ContextCardBlock', 'CompositeCardBlock', 'VisualCardBlock']) {
      final def = library.byName[name]!;
      expect(def.props.map((p) => p.name), ['items', 'layout', 'responsive', 'action', 'gap'], reason: '$name props');
      expect(def.props.firstWhere((p) => p.name == 'layout').defaultValue, 'grid');
      expect(def.props.firstWhere((p) => p.name == 'responsive').defaultValue, true);
    }
    expect(library.byName['SnippetCardItem']!.props.map((p) => p.name), ['id', 'lhs', 'rhs']);
    expect(library.byName['OverviewCardItem']!.props.map((p) => p.name), ['id', 'top', 'bottom']);
    expect(library.byName['ContextCardItem']!.props.map((p) => p.name), ['id', 'title', 'body', 'bgColor', 'bgImageSrc', 'bgImageAlt']);
    expect(library.byName['CompositeCardItem']!.props.map((p) => p.name), ['id', 'header', 'body', 'footer']);
    expect(library.byName['VisualCardItem']!.props.map((p) => p.name), ['body', 'id', 'bgImageSrc', 'tag', 'bgImageAlt']);
  });

  test('old title-first block program no longer parses clean', () {
    final r = parseOpenUI('root = SnippetCardBlock("摘要", [SnippetCardItem("条目")])', library);
    expect(r.errors, isNotEmpty);
  });

  testWidgets('SnippetCardBlock renders lhs/rhs nodes', (tester) async {
    await _pumpCard(tester, 'SnippetCardBlock([SnippetCardItem(null, IconText("search", null, null, "左标题"), Text("text", "右文本")), SnippetCardItem(null, IconText("search", null, null, "左二"), Text("text", "右二"))])');
    expect(find.text('左标题'), findsOneWidget);
    expect(find.text('右文本'), findsOneWidget);
  });

  testWidgets('OverviewCardBlock renders top/bottom nodes', (tester) async {
    await _pumpCard(tester, 'OverviewCardBlock([OverviewCardItem(null, Text("text", "顶部"), MetricIndicatorInline("100", "收入")), OverviewCardItem(null, Text("text", "顶部二"), MetricIndicatorInline("200", "支出"))])');
    expect(find.text('顶部'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('ContextCardItem string title and Tag-node title', (tester) async {
    await _pumpCard(tester, 'ContextCardBlock([ContextCardItem(null, "字符串标题", "正文"), ContextCardItem(null, "字符串标题二", "正文二")])');
    expect(find.text('字符串标题'), findsOneWidget);
    expect(find.text('正文'), findsOneWidget);
    await _pumpCard(tester, 'ContextCardBlock([ContextCardItem(null, Tag("标签标题")), ContextCardItem(null, Tag("标签标题二"))])');
    expect(find.text('标签标题'), findsOneWidget);
  });

  testWidgets('CompositeCardItem renders header, body and footer price/button', (tester) async {
    ActionEvent? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([c])
c = CompositeCardBlock([CompositeCardItem(null, Text("text", "头"), [Text("text", "体一"), Text("text", "体二")], {"price": BoldText("text", "¥9"), "button": Button("买", @ToAssistant("buy"))}), CompositeCardItem(null, Text("text", "头二"), [Text("text", "体三")], {"price": BoldText("text", "¥10"), "button": Button("买二", @ToAssistant("buy2"))})])
''',
            onAction: (e) => seen = e,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('头'), findsOneWidget);
    expect(find.text('体一'), findsOneWidget);
    expect(find.text('体二'), findsOneWidget);
    expect(find.text('¥9'), findsOneWidget);
    await tester.tap(find.text('买'));
    expect(seen?.type, 'toAssistant');
  });

  testWidgets('VisualCardItem renders body, tag and bg image', (tester) async {
    await _pumpCard(tester, 'VisualCardBlock([VisualCardItem(BoldText("text", "视觉体"), null, "https://example.com/bg.png", Tag("视觉标")), VisualCardItem(BoldText("text", "视觉体二"), null, "https://example.com/bg2.png", Tag("视觉标二"))])');
    expect(find.text('视觉体'), findsOneWidget);
    expect(find.text('视觉标'), findsOneWidget);
  });

  testWidgets('grid is default; carousel scrolls horizontally', (tester) async {
    await _pumpCard(tester, 'SnippetCardBlock([SnippetCardItem(null, Text("text", "一")), SnippetCardItem(null, Text("text", "二"))])');
    expect(find.text('一'), findsOneWidget);
    expect(find.text('二'), findsOneWidget);
    await _pumpCard(tester, 'OverviewCardBlock([OverviewCardItem(null, Text("text", "一")), OverviewCardItem(null, Text("text", "二"))], "carousel")');
    final scroller = find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
    expect(scroller, findsOneWidget);
    expect(find.text('一'), findsOneWidget);
    expect(find.text('二'), findsOneWidget);
  });

  testWidgets('SnippetCardBlock carousel falls back to grid', (tester) async {
    await _pumpCard(tester, 'SnippetCardBlock([SnippetCardItem(null, Text("text", "一")), SnippetCardItem(null, Text("text", "二"))], "carousel")');
    final scroller = find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
    expect(scroller, findsNothing);
    expect(find.text('一'), findsOneWidget);
    expect(find.text('二'), findsOneWidget);
  });

  test('card-block unions: min(2), Snippet layout, wrong item type', () {
    final short = parseOpenUI('root = SnippetCardBlock([SnippetCardItem(null, Text("text", "一"))])', library);
    expect(short.root, isNull);
    expect(short.errors.map((e) => e.code), contains('type-mismatch'));
    final carousel = parseOpenUI('root = SnippetCardBlock([SnippetCardItem(null, Text("text", "一")), SnippetCardItem(null, Text("text", "二"))], "carousel")', library);
    expect(carousel.errors.map((e) => e.code), contains('type-mismatch'));
    expect((carousel.root!.props['layout'] as String), 'grid');
    final wrongItem = parseOpenUI('root = SnippetCardBlock([SnippetCardItem(null, Text("text", "一")), Text("text", "二")])', library);
    expect(wrongItem.errors.map((e) => e.code), contains('type-mismatch'));
    expect(wrongItem.root, isNull, reason: 'filtering leaves 1 item, under min(2)');
  });

  testWidgets('block action dispatches on tap', (tester) async {
    ActionEvent? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([b])
b = SnippetCardBlock([SnippetCardItem(null, Text("text", "点我块")), SnippetCardItem(null, Text("text", "点我块二"))], "grid", true, @ToAssistant("blocktap"))
''',
            onAction: (e) => seen = e,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('点我块'));
    expect(seen?.type, 'toAssistant');
    expect(seen?.args.first, 'blocktap');
  });
}
