import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

/// Conformance scaffolding (Task 9; Task 10 fills in the React-docs
/// programs).
///
/// One test per example screen. The example widgets themselves live in
/// example/lib/screens.dart and are pumped by example/test/screens_test.
/// This package's suite cannot import them — example/ is a separate
/// package that depends on this one, so a path dev_dependency back would
/// be circular. Instead each test below pumps the renderer's controller
/// or old mode with the exact Lang program its example screen uses, so a
/// program that breaks in the example breaks here too. Keep the programs
/// below in sync with screens.dart when either side changes.

void main() {
  testWidgets('conformance: chat rich answer screen program', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIStandardLibrary(),
            response: '''
root = Stack([header, note, table, chart, callout])
header = CardHeader("Q1 收入", "全部业务线")
note = TextContent("一季度收入稳步增长，3 月创单月新高。")
table = Table([m, v])
m = Col("月份", ["1月", "2月", "3月"])
v = Col("收入（万）", [120, 145, 180])
chart = BarChart(["1月", "2月", "3月"], [rev])
rev = Series("收入", [120, 145, 180])
callout = Callout("提示：3 月含一笔大客户回款。", "info")
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Q1 收入'), findsOneWidget);
  });

  testWidgets('conformance: dashboard screen program', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIStandardLibrary(),
            response: '''
root = Stack([title, hbar, radar, pie, heat, mini])
title = CardHeader("业务看板", "各维度一览")
hbar = HorizontalBarChart(["华北", "华东", "华南"], [s1])
s1 = Series("销售额", [320, 280, 240])
radar = RadarChart(["质量", "速度"], [rs])
rs = Series("本季", [80, 65])
pie = PieChart([p1, p2])
p1 = Slice("线上", 60)
p2 = Slice("线下", 40)
heat = HeatmapChart(["周一", "周二"], [h1])
h1 = Series("访问量", [10, 30])
mini = MiniBarChart([5, 12, 8, 20])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('业务看板'), findsOneWidget);
  });

  testWidgets('conformance: form + Query screen program', (tester) async {
    Future<Object?> provider(String tool, Map<String, Object?> params) async {
      if (tool != 'get_weather') throw StateError('unknown tool $tool');
      return {'rows': ['晴', '多云', '雨']};
    }

    final controller = OpenUIController(
      library: openUIStandardLibrary(),
      toolProvider: provider,
      initialState: const {'city': '北京'},
    );
    addTearDown(controller.dispose);
    controller.push('''
root = Stack([title, form, count, retry])
title = CardHeader("城市天气", "输入城市，查询返回行数")
form = Form([city])
city = Input("城市", "city")
count = TextContent("" + @Count(weather.rows))
weather = Query("get_weather", {"city": \$city}, {"rows": []})
retry = Button("刷新", Action([@Run(weather)]))
''');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIStandardLibrary(),
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('城市天气'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('conformance: custom component + theme screen program',
      (tester) async {
    final registry = ComponentRegistry().withBuilder(
      'Callout',
      (context, node, renderChild) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('宿主自定义 Callout'),
          Text(node.props['text'] as String? ?? ''),
        ],
      ),
    );
    final controller = OpenUIController(
      library: openUIStandardLibrary(),
      theme: OpenUIThemeData.dark(),
      registry: registry,
    );
    addTearDown(controller.dispose);
    controller.push('''
root = Stack([title, callout, note])
title = CardHeader("主题与自定义组件", "切换主题，Callout 已被替换")
callout = Callout("这是被替换的 Callout", "info")
note = TextContent("下面的 Callout 不是内置渲染，而是宿主通过 registry 替换的。")
''');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIStandardLibrary(),
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('宿主自定义 Callout'), findsOneWidget);
    expect(find.text('这是被替换的 Callout'), findsOneWidget);
  });
}
