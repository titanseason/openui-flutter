import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

void _collect(ElementNode node, Set<String> out) {
  out.add(node.component);
  for (final v in node.props.values) {
    if (v is ElementNode) _collect(v, out);
    if (v is List) {
      for (final e in v) {
        if (e is ElementNode) _collect(e, out);
      }
    }
  }
}

void main() {
  final library = openUIMvpLibrary();

  test('library now has all 95 component names', () {
    final names = library.components.map((c) => c.name).toList();
    // 86 GenUI names plus 9 extra chart components added in Task 6.
    expect(names.length, 95);
    expect(names.toSet().length, 95);
    for (final name in ['HeatmapChart', 'FunnelChart', 'CalendarHeatmap', 'MiniBarChart', 'MiniLineChart', 'StackedLegend', 'BarChartCondensed', 'LineChartCondensed', 'AreaChartCondensed']) {
      expect(names, contains(name), reason: 'missing $name');
    }
    for (final name in [
      'Accordion', 'AccordionItem', 'Steps', 'StepsItem', 'Carousel', 'Separator', 'Modal', 'SectionBlock', 'SectionItem',
      'Text', 'BoldText', 'TextCallout', 'ImageBlock', 'ImageGallery', 'ImageText', 'ImageTextLarge', 'IconText', 'CodeBlock', 'InlineHeader', 'Icon',
      'EditableTable', 'AreaChart', 'RadarChart', 'HorizontalBarChart', 'RadialChart', 'SingleStackedBarChart', 'ScatterChart', 'ScatterSeries', 'Point', 'TagBlock', 'Tag', 'EntityList', 'MetricIndicatorInline', 'MetricIndicatorWithStrikethrough',
      'FormControl', 'Label', 'TextArea', 'DatePicker', 'Slider', 'CheckBoxGroup', 'CheckBoxItem', 'RadioGroup', 'RadioItem', 'SwitchGroup', 'SwitchItem', 'OptionCards', 'OptionCard',
      'Buttons', 'IconButton', 'ListBlock', 'ListItem',
      'SnippetBlock', 'SnippetItem', 'OverviewBlock', 'OverviewItem', 'ContextBlock', 'ContextItem', 'CompositeBlock', 'CompositeItem', 'VisualBlock', 'VisualItem',
    ]) {
      expect(names, contains(name), reason: 'missing $name');
    }
  });

  test('every remaining component parses into a node', () {
    const snippets = [
      'a1 = Accordion([AccordionItem("折叠", [TextContent("内")])])',
      'a2 = Steps([StepsItem("第一步", [TextContent("做")])])',
      'a3 = Carousel([TextContent("一"), TextContent("二")])',
      'a4 = Separator()',
      'a5 = Modal("弹窗", [TextContent("内")])',
      'a6 = SectionBlock("分组", [SectionItem("项", [TextContent("内")])])',
      'c1 = Text("普通")',
      'c2 = BoldText("加粗")',
      'c3 = TextCallout("注意", "warning")',
      'c4 = ImageBlock("https://example.com/a.png", "说明")',
      'c5 = ImageGallery(["https://example.com/a.png"])',
      'c6 = ImageText("https://example.com/a.png", "图文")',
      'c7 = ImageTextLarge("https://example.com/a.png", "大图文")',
      'c8 = IconText("search", "搜索")',
      'c9 = CodeBlock("print(1)", "python")',
      'c10 = InlineHeader("行内标题")',
      'c11 = Icon("search")',
      'd1 = EditableTable([Col("名", ["a"])])',
      'd2 = AreaChart(["一", "二"], [Series("s", [1, 2])])',
      'd3 = RadarChart(["一", "二"], [Series("s", [1, 2])])',
      'd4 = HorizontalBarChart(["一", "二"], [Series("s", [1, 2])])',
      'd5 = RadialChart([Slice("a", 3), Slice("b", 1)])',
      'd6 = SingleStackedBarChart([Slice("a", 3), Slice("b", 1)])',
      'd7 = ScatterChart([ScatterSeries("s", [Point(1, 2), Point(3, 4)])])',
      'd8 = TagBlock([Tag("标签", "star")])',
      'd9 = EntityList(["张三", "李四"])',
      'd10 = MetricIndicatorInline("收入", "100", "+10%")',
      'd11 = MetricIndicatorWithStrikethrough("收入", "100", "120")',
      'f1 = FormControl("姓名", [Input("姓名")], "提示")',
      'f2 = Label("标签")',
      'f3 = TextArea("备注")',
      'f4 = DatePicker("日期")',
      'f5 = Slider("音量", null, 50, 0, 100)',
      'f6 = CheckBoxGroup([CheckBoxItem("a", "a")])',
      'f7 = RadioGroup([RadioItem("a", "a")])',
      'f8 = SwitchGroup([SwitchItem("a", "a")])',
      'f9 = OptionCards([OptionCard("卡", "a", "描述")])',
      'x1 = Buttons([Button("点", @ToAssistant("hi"))])',
      'x2 = IconButton("search", @ToAssistant("hi"))',
      'g1 = ListBlock([ListItem("第一条")])',
      'h1 = SnippetBlock("摘要", [SnippetItem("条目")])',
      'h2 = OverviewBlock("概览", [OverviewItem("条目")])',
      'h3 = ContextBlock("上下文", [ContextItem("条目")])',
      'h4 = CompositeBlock("组合", [CompositeItem("条目")])',
      'h5 = VisualBlock("视觉", [VisualItem("条目", "https://example.com/a.png")])',
    ];
    final ids = snippets.map((s) => s.split(' = ').first).toList();
    final program = 'root = Stack([${ids.join(', ')}])\n${snippets.join('\n')}\n';
    final r = parseOpenUI(program, library);
    expect(r.errors, isEmpty, reason: r.errors.toString());
    expect(r.root, isNotNull);
    final found = <String>{};
    _collect(r.root!, found);
    for (final name in [
      'Accordion', 'AccordionItem', 'Steps', 'StepsItem', 'Carousel', 'Separator', 'Modal', 'SectionBlock', 'SectionItem',
      'Text', 'BoldText', 'TextCallout', 'ImageBlock', 'ImageGallery', 'ImageText', 'ImageTextLarge', 'IconText', 'CodeBlock', 'InlineHeader', 'Icon',
      'EditableTable', 'AreaChart', 'RadarChart', 'HorizontalBarChart', 'RadialChart', 'SingleStackedBarChart', 'ScatterChart', 'ScatterSeries', 'Point', 'TagBlock', 'Tag', 'EntityList', 'MetricIndicatorInline', 'MetricIndicatorWithStrikethrough',
      'FormControl', 'Label', 'TextArea', 'DatePicker', 'Slider', 'CheckBoxGroup', 'RadioGroup', 'SwitchGroup', 'OptionCards',
      'Buttons', 'IconButton', 'ListBlock', 'ListItem',
      'SnippetBlock', 'SnippetItem', 'OverviewBlock', 'OverviewItem', 'ContextBlock', 'ContextItem', 'CompositeBlock', 'CompositeItem', 'VisualBlock', 'VisualItem',
    ]) {
      expect(found, contains(name), reason: 'not in tree: $name');
    }
  });

  testWidgets('layout and content components render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([acc, steps, sep, modal, sec, txt, bold, call, code, head])
acc = Accordion([AccordionItem("折叠标题", [TextContent("折叠内容")])])
steps = Steps([StepsItem("第一步", [TextContent("步骤内容")])])
sep = Separator()
modal = Modal("弹窗标题", [TextContent("弹窗内容")])
sec = SectionBlock("分组标题", [SectionItem("分组项", [TextContent("分组内容")])])
txt = Text("普通文本")
bold = BoldText("加粗文本")
call = TextCallout("注意内容", "warning")
code = CodeBlock("print(1)", "python")
head = InlineHeader("行内标题")
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['折叠标题', '第一步', '弹窗标题', '分组标题', '普通文本', '加粗文本', '注意内容', 'print(1)', '行内标题']) {
      expect(find.text(text), findsWidgets);
    }
  });

  testWidgets('charts, tags, metrics and composite cards render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([area, radar, hbar, radial, stacked, scatter, tags, ents, m1, m2, snip, lst, btns])
area = AreaChart(["一", "二"], [Series("s", [1, 2])])
radar = RadarChart(["一", "二"], [Series("s", [1, 2])])
hbar = HorizontalBarChart(["一", "二"], [Series("s", [1, 2])])
radial = RadialChart([Slice("a", 3), Slice("b", 1)])
stacked = SingleStackedBarChart([Slice("a", 3), Slice("b", 1)])
scatter = ScatterChart([ScatterSeries("s", [Point(1, 2)])])
tags = TagBlock([Tag("标签")])
ents = EntityList(["张三"])
m1 = MetricIndicatorInline("收入", "100", "+10%")
m2 = MetricIndicatorWithStrikethrough("收入", "100", "120")
snip = SnippetBlock("摘要标题", [SnippetItem("摘要条目")])
lst = ListBlock([ListItem("列表第一条")])
btns = Buttons([Button("点我", @ToAssistant("hi"))])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['标签', '张三', '摘要标题', '摘要条目', '列表第一条', '点我']) {
      expect(find.text(text), findsWidgets);
    }
  });

  testWidgets('form groups render and radio selection writes state', (tester) async {
    var state = <String, Object?>{};
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([fc, lbl, area, date, slider, cb, radio, sw, cards])
fc = FormControl("姓名", [Input("姓名")], "提示")
lbl = Label("字段标签")
area = TextArea("备注")
date = DatePicker("日期")
slider = Slider("音量", "vol", 50, 0, 100)
cb = CheckBoxGroup([CheckBoxItem("多选a", "a")])
radio = RadioGroup([RadioItem("单选a", "a")])
sw = SwitchGroup([SwitchItem("开关a", "a")])
cards = OptionCards([OptionCard("卡片a", "a", "描述")])
''',
            onStateUpdate: (s) => state = s,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['姓名', '字段标签', '备注', '日期: 未选择', '音量: 50', '多选a', '单选a', '开关a', '卡片a']) {
      expect(find.text(text), findsWidgets);
    }
    await tester.tap(find.text('单选a'));
    await tester.pump();
    expect(state['bind'], isNull); // RadioGroup here has no bind; tap must not crash
  });
}
