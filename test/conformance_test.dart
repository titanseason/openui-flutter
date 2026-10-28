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

  testWidgets('conformance: React docs card + bar chart + form + tabs',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIStandardLibrary(),
            response: '''
root = Stack([card, form, tabs])
card = Card([chead, cbody, chart])
chead = CardHeader("东京天气", "未来三天")
cbody = TextContent("数据来自示例工具。")
chart = BarChart(["周一", "周二", "周三"], [s])
s = Series("气温", [22, 24, 21])
form = Form([city])
city = Input("城市", "city")
tabs = Tabs([t1, t2])
t1 = TabItem("概览", [TextContent("概览内容")])
t2 = TabItem("明细", [TextContent("明细内容")])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('东京天气'), findsOneWidget);
    expect(find.text('气温'), findsOneWidget);
    expect(find.text('城市'), findsOneWidget);
    expect(find.text('概览'), findsWidgets);
  });

  testWidgets('conformance: weather Query example shows forecast data',
      (tester) async {
    Map<String, Object?>? seenParams;
    Future<Object?> provider(String tool, Map<String, Object?> params) async {
      if (tool != 'get_weather') throw StateError('unknown tool $tool');
      seenParams = params;
      return {
        'rows': [
          {'day': '周一', 'condition': '晴'},
          {'day': '周二', 'condition': '雨'},
          {'day': '周三', 'condition': '晴'},
        ],
      };
    }

    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIStandardLibrary(),
            response: '''
root = Stack([count, sunny, first])
count = TextContent("" + @Count(weather.rows))
sunny = TextContent("" + @Count(@Filter(weather.rows, "condition", "==", "晴")))
first = TextContent(sunnyRows[0].day)
sunnyRows = @Filter(weather.rows, "condition", "==", "晴")
weather = Query("get_weather", {"city": "Tokyo"}, {})
''',
            toolProvider: provider,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(seenParams?['city'], 'Tokyo');
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('周一'), findsOneWidget);
  });

  testWidgets('conformance: Mutation retry example refetches Queries',
      (tester) async {
    var queryCalls = 0;
    var mutationCalls = 0;
    Map<String, Object?>? mutationParams;
    Future<Object?> provider(String tool, Map<String, Object?> params) async {
      if (tool == 'list_deploys') {
        queryCalls++;
        return {
          'rows': [1]
        };
      }
      if (tool == 'retry_deployment') {
        mutationCalls++;
        mutationParams = params;
        return {'ok': true};
      }
      return null;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIStandardLibrary(),
            response: '''
root = Stack([count, btn])
count = TextContent("" + @Count(deploys.rows))
deploys = Query("list_deploys", {"project": "prod"}, {"rows": []})
btn = Button("重试部署", Action([@Run(retry)]))
retry = Mutation("retry_deployment", {"project": "prod"})
''',
            toolProvider: provider,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('重试部署'));
    await tester.pumpAndSettle();
    expect(mutationCalls, 1);
    expect(mutationParams?['project'], 'prod');
    expect(queryCalls, 2);
  });

  testWidgets('golden: bar chart', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: OpenUIRenderer(
              library: openUIStandardLibrary(),
              response: '''
root = BarChart(["周一", "周二", "周三"], [s])
s = Series("气温", [22, 24, 21])
''',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/chart_bar.png'),
    );
  });

  testWidgets('golden: card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 200,
            child: OpenUIRenderer(
              library: openUIStandardLibrary(),
              response: '''
root = Card([chead, cbody])
chead = CardHeader("东京天气", "未来三天")
cbody = TextContent("数据来自示例工具。")
''',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/card.png'),
    );
  });
}
