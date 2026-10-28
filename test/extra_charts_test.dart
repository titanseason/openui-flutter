import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

void main() {
  test('extra chart components are in the library', () {
    final names = openUIMvpLibrary().components.map((c) => c.name).toSet();
    expect(names, containsAll(['HeatmapChart', 'FunnelChart', 'CalendarHeatmap', 'MiniBarChart', 'MiniLineChart', 'StackedLegend', 'BarChartCondensed', 'LineChartCondensed', 'AreaChartCondensed']));
  });

  testWidgets('funnel and heatmap render without crashing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIMvpLibrary(),
            response: '''
root = Stack([fun, heat])
fun = FunnelChart([Slice("访问", 100), Slice("下单", 60), Slice("支付", 30)])
heat = HeatmapChart(["一", "二"], [Series("s", [1, 2])])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['访问 (100.0)', '下单 (60.0)', '支付 (30.0)']) {
      expect(find.text(text), findsWidgets);
    }
  });

  testWidgets('migrated charts render with labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIMvpLibrary(),
            response: '''
root = Stack([bar, line, area, hbar, pie, radar, radial, stacked, scatter])
bar = BarChart(["一", "二"], [Series("柱", [1, 2])])
line = LineChart(["一", "二"], [Series("线", [1, 2])])
area = AreaChart(["一", "二"], [Series("面", [1, 2])])
hbar = HorizontalBarChart(["一", "二"], [Series("横", [1, 2])])
pie = PieChart([Slice("饼一", 3), Slice("饼二", 1)])
radar = RadarChart(["一", "二"], [Series("雷达", [1, 2])])
radial = RadialChart([Slice("径一", 3), Slice("径二", 1)])
stacked = SingleStackedBarChart([Slice("堆一", 3), Slice("堆二", 1)])
scatter = ScatterChart([ScatterSeries("散", [Point(1, 2), Point(3, 4)])])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['柱', '线', '面', '横', '饼一 (3.0)', '饼二 (1.0)', '雷达', '径一 (3.0)', '径二 (1.0)', '堆一 (75%)', '堆二 (25%)', '散']) {
      expect(find.text(text), findsWidgets);
    }
  });

  testWidgets('mini, condensed, stacked legend and calendar heatmap render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIMvpLibrary(),
            response: '''
root = Stack([mini, minib, cond, leg, cal])
mini = MiniLineChart([1, 2, 3])
minib = MiniBarChart([1, 2, 3])
cond = BarChartCondensed(["一", "二"], [Series("紧", [1, 2])])
leg = StackedLegend([Series("图例一", [1]), Series("图例二", [2])])
cal = CalendarHeatmap([{date: "2026-10-01", value: 3}, {date: "2026-10-02", value: 1}])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Condensed charts hide their legend (see the next test), so the
    // condensed series label must not appear; the legend labels do.
    // Mini charts have no labels by design, so only the pump matters for them.
    expect(find.text('紧'), findsNothing);
    expect(find.text('图例一'), findsWidgets);
    expect(find.text('图例二'), findsWidgets);
  });

  testWidgets('condensed charts hide the legend row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIMvpLibrary(),
            response: '''
root = Stack([c1, c2])
c1 = LineChartCondensed(["一", "二"], [Series("折紧", [1, 2])])
c2 = AreaChartCondensed(["一", "二"], [Series("面紧", [1, 2])])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Legend labels are rendered by the full charts only; condensed
    // charts show no legend row, so the series labels must not appear.
    expect(find.text('折紧'), findsNothing);
    expect(find.text('面紧'), findsNothing);
  });

  testWidgets('radar chart with an empty series renders without crashing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIMvpLibrary(),
            response: '''
root = RadarChart(["一", "二"], [])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The bordered empty box, not a fl_chart assertion failure.
    expect(find.byType(FlRadarChartWidget), findsOneWidget);
  });

  testWidgets('radar chart honours a custom theme palette', (tester) async {
    final controller = OpenUIController(
      library: openUIMvpLibrary(),
      theme: OpenUIThemeData(
        colors: OpenUIThemeData.light().colors,
        chartPalette: const [Colors.red, Colors.red],
      ),
    );
    controller.push('''
root = RadarChart(["一", "二"], [Series("雷达", [1, 2])])
''');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: OpenUIRenderer(library: controller.library, controller: controller))),
    );
    await tester.pumpAndSettle();
    expect(find.text('雷达'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Container && w.color == Colors.red),
      findsOneWidget,
    );
    controller.dispose();
  });
}
