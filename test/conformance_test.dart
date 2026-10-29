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
header = CardHeader("Q1 Revenue", "All business lines")
note = TextContent("Q1 revenue grew steadily, with March hitting a monthly high.")
table = Table([m, v])
m = Col("Month", ["Jan", "Feb", "Mar"])
v = Col("Revenue (10k)", [120, 145, 180])
chart = BarChart(["Jan", "Feb", "Mar"], [rev])
rev = Series("Revenue", [120, 145, 180])
callout = Callout("Note: March includes a large client payment.", "info")
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Q1 Revenue'), findsOneWidget);
  });

  testWidgets('conformance: dashboard screen program', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIStandardLibrary(),
            response: '''
root = Stack([title, hbar, radar, pie, bar, trend])
title = CardHeader("Business Dashboard", "All dimensions at a glance")
hbar = HorizontalBarChart(["North", "East", "South"], [s1])
s1 = Series("Sales", [320, 280, 240])
radar = RadarChart(["Quality", "Speed"], [rs])
rs = Series("This quarter", [80, 65])
pie = PieChart([p1, p2])
p1 = Slice("Online", 60)
p2 = Slice("Offline", 40)
bar = BarChart(["Mon", "Tue"], [h1])
h1 = Series("Visits", [10, 30])
trend = LineChart(["W1", "W2", "W3", "W4"], [t1])
t1 = Series("Trend", [5, 12, 8, 20])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Business Dashboard'), findsOneWidget);
    // The pie has no values array: its Slice nodes supply the data
    // (React's buildSliceData fallback), so the slice labels render.
    expect(find.textContaining('Online'), findsOneWidget);
    expect(find.textContaining('Offline'), findsOneWidget);
  });

  testWidgets('conformance: form + Query screen program', (tester) async {
    Future<Object?> provider(String tool, Map<String, Object?> params) async {
      if (tool != 'get_weather') throw StateError('unknown tool $tool');
      return {'rows': ['Sunny', 'Cloudy', 'Rain']};
    }

    final controller = OpenUIController(
      library: openUIStandardLibrary(),
      toolProvider: provider,
      initialState: const {'city': 'Beijing'},
    );
    addTearDown(controller.dispose);
    controller.push('''
root = Stack([title, form, count, retry])
title = CardHeader("City Weather", "Type a city, see the row count")
form = Form("weather", Buttons([Button("Submit", @ToAssistant("submit"))]), [fc])
fc = FormControl("City", Input("city"))
count = TextContent("" + @Count(weather.rows))
weather = Query("get_weather", {"city": \$city}, {"rows": []})
retry = Button("Refresh", Action([@Run(weather)]))
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
    expect(find.text('City Weather'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('conformance: custom component + theme screen program',
      (tester) async {
    final registry = ComponentRegistry().withBuilder(
      'Callout',
      (context, node, renderChild) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Host Custom Callout'),
          Text(node.props['description'] as String? ?? ''),
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
title = CardHeader("Theme & Custom Components", "Switch theme, Callout is replaced")
callout = Callout("info", "Replaced Callout", "This is the replaced Callout")
note = TextContent("The Callout below is not the built-in rendering, but a host replacement via the registry.")
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
    expect(find.text('Host Custom Callout'), findsOneWidget);
    expect(find.text('This is the replaced Callout'), findsOneWidget);
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
form = Form("weather", Buttons([Button("查询", @ToAssistant("查询"))]), [fc])
fc = FormControl("城市", Input("city"))
tabs = Tabs([t1, t2])
t1 = TabItem("overview", "概览", [TextContent("概览内容")])
t2 = TabItem("detail", "明细", [TextContent("明细内容")])
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

  testWidgets('golden: line chart', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: OpenUIRenderer(
              library: openUIStandardLibrary(),
              response: '''
root = LineChart(["周一", "周二", "周三"], [s])
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
      matchesGoldenFile('goldens/chart_line.png'),
    );
  });

  testWidgets('golden: radar chart', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: OpenUIRenderer(
              library: openUIStandardLibrary(),
              response: '''
root = RadarChart(["A", "B", "C"], [s])
s = Series("R", [10, 20, 30])
''',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/chart_radar.png'),
    );
  });

  testWidgets('golden: horizontal bar chart', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: OpenUIRenderer(
              library: openUIStandardLibrary(),
              response: '''
root = HorizontalBarChart(["North", "East", "South"], [s])
s = Series("Sales", [30, 50, 20])
''',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/chart_hbar.png'),
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
