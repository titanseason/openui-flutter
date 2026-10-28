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
  final library = openUIStandardLibrary();

  test('libraries now have all 95 component names between them', () {
    // Split libraries: general 91 (no chat-only 4), chat 93 (no Stack
    // or Modal); the union is the full 95 (86 GenUI + 9 extras).
    final general = openUIStandardLibrary();
    final chat = openUIChatLibrary();
    expect(general.root, 'Stack');
    expect(chat.root, 'Card');
    expect(general.components.length, 91);
    expect(chat.components.length, 93);
    for (final name in ['FollowUpBlock', 'FollowUpItem', 'SectionBlock', 'SectionItem']) {
      expect(general.byName[name], isNull, reason: '$name must not be in the general library');
      expect(chat.byName[name], isNotNull, reason: '$name must be in the chat library');
    }
    for (final name in ['Stack', 'Modal']) {
      expect(general.byName[name], isNotNull, reason: '$name must be in the general library');
      expect(chat.byName[name], isNull, reason: '$name must not be in the chat library');
    }
    final names = {...general.components.map((c) => c.name), ...chat.components.map((c) => c.name)}.toList();
    expect(names.length, 95);
    for (final name in ['HeatmapChart', 'FunnelChart', 'CalendarHeatmap', 'MiniBarChart', 'MiniLineChart', 'StackedLegend', 'BarChartCondensed', 'LineChartCondensed', 'AreaChartCondensed']) {
      expect(names, contains(name), reason: 'missing $name');
    }
    for (final name in [
      'Accordion', 'AccordionItem', 'Steps', 'StepsItem', 'Carousel', 'Separator', 'Modal', 'SectionBlock', 'SectionItem',
      'Text', 'BoldText', 'TextCallout', 'ImageBlock', 'ImageGallery', 'ImageText', 'ImageTextLarge', 'IconText', 'CodeBlock', 'InlineHeader', 'Icon',
      'EditableTable', 'AreaChart', 'RadarChart', 'HorizontalBarChart', 'RadialChart', 'SingleStackedBarChart', 'ScatterChart', 'ScatterSeries', 'Point', 'TagBlock', 'Tag', 'EntityList', 'MetricIndicatorInline', 'MetricIndicatorWithStrikethrough',
      'FormControl', 'Label', 'TextArea', 'DatePicker', 'Slider', 'CheckBoxGroup', 'CheckBoxItem', 'RadioGroup', 'RadioItem', 'SwitchGroup', 'SwitchItem', 'OptionCards', 'OptionCard',
      'Buttons', 'IconButton', 'ListBlock', 'ListItem',
      'SnippetCardBlock', 'SnippetCardItem', 'OverviewCardBlock', 'OverviewCardItem', 'ContextCardBlock', 'ContextCardItem', 'CompositeCardBlock', 'CompositeCardItem', 'VisualCardBlock', 'VisualCardItem',
    ]) {
      expect(names, contains(name), reason: 'missing $name');
    }
  });

  test('every remaining component parses into a node', () {
    const snippets = [
      'a1 = Accordion([AccordionItem("acc", "折叠", [TextContent("内")])])',
      'a2 = Steps([StepsItem("第一步", "做")])',
      'a3 = Carousel([[TextContent("一")], [TextContent("二")]])',
      'a4 = Separator()',
      'a5 = Modal("弹窗", true, [TextContent("内")])',
      'a6 = ListBlock([ListItem("列表项")])',
      'c1 = Text("普通")',
      'c2 = BoldText("加粗")',
      'c3 = TextCallout("warning", "注意", "请注意")',
      'c4 = ImageBlock("https://example.com/a.png", "说明")',
      'c5 = ImageGallery(["https://example.com/a.png"])',
      'c6 = ImageText("https://example.com/a.png", "alt文本", "图文")',
      'c7 = ImageTextLarge("https://example.com/a.png", "alt文本", "大图文")',
      'c8 = IconText("search", "neutral", "m", "搜索")',
      'c9 = CodeBlock("python", "print(1)")',
      'c10 = InlineHeader("行内标题")',
      'c11 = Icon("search")',
      'd1 = EditableTable("t", [{"type": "text", "key": "name", "header": "名"}], [{"id": "r1", "values": ["a"]}])',
      'd2 = AreaChart(["一", "二"], [Series("s", [1, 2])])',
      'd3 = RadarChart(["一", "二"], [Series("s", [1, 2])])',
      'd4 = HorizontalBarChart(["一", "二"], [Series("s", [1, 2])])',
      'd5 = RadialChart(["a", "b"], [3, 1])',
      'd6 = SingleStackedBarChart(["a", "b"], [3, 1])',
      'd7 = ScatterChart([ScatterSeries("s", [Point(1, 2), Point(3, 4)])])',
      'd8 = TagBlock(["标签", "标签二"])',
      'd8b = Tag("标签", "star")',
      'd9 = EntityList([{"left": "张三", "right": "值一"}, {"left": "李四", "right": "值二"}])',
      'd10 = MetricIndicatorInline("100", "收入", {"direction": "up", "value": 10})',
      'd11 = MetricIndicatorWithStrikethrough("100", "收入", "120")',
      'f1 = FormControl("姓名", Input("name"), "提示")',
      'f2 = Label("标签")',
      'f3 = TextArea("note")',
      'f4 = DatePicker("date")',
      'f5 = Slider("vol", "continuous", 0, 100, null, null, "音量", null, [50])',
      'f6 = CheckBoxGroup("cb", [CheckBoxItem("多选a", "desc", "a")])',
      'f7 = RadioGroup("rg", [RadioItem("单选a", "desc", "a")])',
      'f8 = SwitchGroup("sw", [SwitchItem("开关a", "desc", "a")])',
      'f9 = OptionCards("oc", "single", [OptionCard("a", "卡", "描述")])',
      'x1 = Buttons([Button("点", @ToAssistant("hi"))])',
      'x2 = IconButton("搜索", "search", @ToAssistant("hi"))',
      'g1 = ListBlock([ListItem("第一条")])',
      'h1 = SnippetCardBlock([SnippetCardItem(null, IconText("search", null, null, "摘要左"), Text("摘要右"))])',
      'h2 = OverviewCardBlock([OverviewCardItem(null, IconText("search", null, null, "概览顶"), MetricIndicatorInline("100", "收入"))])',
      'h3 = ContextCardBlock([ContextCardItem(null, "上下文标题", "上下文正文")])',
      'h4 = CompositeCardBlock([CompositeCardItem(null, Text("组合头"), [Text("组合体")], {"price": BoldText("¥9"), "button": Button("买", @ToAssistant("buy"))})])',
      'h5 = VisualCardBlock([VisualCardItem(BoldText("视觉体"), null, null, Tag("视觉标"))])',
    ];
    final ids = snippets.map((s) => s.split(' = ').first).toList();
    final program = 'root = Stack([${ids.join(', ')}])\n${snippets.join('\n')}\n';
    final r = parseOpenUI(program, library);
    expect(r.errors, isEmpty, reason: r.errors.toString());
    expect(r.root, isNotNull);
    final found = <String>{};
    _collect(r.root!, found);
    // Chat-only components live in the chat library, under a Card root.
    final chatProgram = '''
root = Card([sec, fol])
sec = SectionBlock([SectionItem("sec", "分组", [TextContent("内")])])
fol = FollowUpBlock([FollowUpItem("追问")])
''';
    final chatResult = parseOpenUI(chatProgram, openUIChatLibrary());
    expect(chatResult.errors, isEmpty, reason: chatResult.errors.toString());
    expect(chatResult.root, isNotNull);
    _collect(chatResult.root!, found);
    for (final name in [
      'Accordion', 'AccordionItem', 'Steps', 'StepsItem', 'Carousel', 'Separator', 'Modal', 'SectionBlock', 'SectionItem', 'FollowUpBlock', 'FollowUpItem',
      'Text', 'BoldText', 'TextCallout', 'ImageBlock', 'ImageGallery', 'ImageText', 'ImageTextLarge', 'IconText', 'CodeBlock', 'InlineHeader', 'Icon',
      'EditableTable', 'AreaChart', 'RadarChart', 'HorizontalBarChart', 'RadialChart', 'SingleStackedBarChart', 'ScatterChart', 'ScatterSeries', 'Point', 'TagBlock', 'Tag', 'EntityList', 'MetricIndicatorInline', 'MetricIndicatorWithStrikethrough',
      'FormControl', 'Label', 'TextArea', 'DatePicker', 'Slider', 'CheckBoxGroup', 'RadioGroup', 'SwitchGroup', 'OptionCards',
      'Buttons', 'IconButton', 'ListBlock', 'ListItem',
      'SnippetCardBlock', 'SnippetCardItem', 'OverviewCardBlock', 'OverviewCardItem', 'ContextCardBlock', 'ContextCardItem', 'CompositeCardBlock', 'CompositeCardItem', 'VisualCardBlock', 'VisualCardItem',
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
root = Stack([acc, steps, sep, modal, txt, bold, call, code, head])
acc = Accordion([AccordionItem("acc", "折叠标题", [TextContent("折叠内容")])])
steps = Steps([StepsItem("第一步", "步骤内容")])
sep = Separator()
modal = Modal("弹窗标题", true, [TextContent("弹窗内容")])
txt = Text("普通文本")
bold = BoldText("加粗文本")
call = TextCallout("warning", "注意", "注意内容")
code = CodeBlock("python", "print(1)")
head = InlineHeader("行内标题")
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['折叠标题', '第一步', '弹窗标题', '普通文本', '加粗文本', '注意内容', 'print(1)', '行内标题']) {
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
radial = RadialChart(["a", "b"], [3, 1])
stacked = SingleStackedBarChart(["a", "b"], [3, 1])
scatter = ScatterChart([ScatterSeries("s", [Point(1, 2)])])
tags = TagBlock(["标签"])
ents = EntityList([{"left": "张三", "right": "详情"}])
m1 = MetricIndicatorInline("100", "收入", {"direction": "up", "value": 10})
m2 = MetricIndicatorWithStrikethrough("100", "收入", "120")
snip = SnippetCardBlock([SnippetCardItem(null, IconText("search", null, null, "摘要左"), Text("摘要右"))])
lst = ListBlock([ListItem("列表第一条")])
btns = Buttons([Button("点我", @ToAssistant("hi"))])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['标签', '张三', '摘要左', '摘要右', '列表第一条', '点我']) {
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
fc = FormControl("姓名", Input("name"), "提示")
lbl = Label("字段标签")
area = TextArea("note")
date = DatePicker("date")
slider = Slider("vol", "continuous", 0, 100, null, null, "音量", null, [50])
cb = CheckBoxGroup("cb", [CheckBoxItem("多选a", "desc", "a")])
radio = RadioGroup("rg", [RadioItem("单选a", "desc", "a")])
sw = SwitchGroup("sw", [SwitchItem("开关a", "desc", "a")])
cards = OptionCards("oc", "single", [OptionCard("a", "卡片a", "描述")])
''',
            onStateUpdate: (s) => state = s,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['姓名', '提示', '字段标签', '未选择', '音量: 50', '多选a', '单选a', '开关a', '卡片a']) {
      expect(find.text(text), findsWidgets);
    }
    await tester.tap(find.text('单选a'));
    await tester.pump();
    expect(state['rg'], 'a');
  });
}
