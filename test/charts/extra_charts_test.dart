import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

void main() {
  testWidgets('migrated charts render with labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIStandardLibrary(),
            response: '''
root = Stack([bar, line, area, hbar, pie, radar, radial, stacked, scatter])
bar = BarChart(["一", "二"], [Series("柱", [1, 2])])
line = LineChart(["一", "二"], [Series("线", [1, 2])])
area = AreaChart(["一", "二"], [Series("面", [1, 2])])
hbar = HorizontalBarChart(["一", "二"], [Series("横", [1, 2])])
pie = PieChart(["饼一", "饼二"], [3, 1])
radar = RadarChart(["一", "二"], [Series("雷达", [1, 2])])
radial = RadialChart(["径一", "径二"], [3, 1])
stacked = SingleStackedBarChart(["堆一", "堆二"], [3, 1])
scatter = ScatterChart([ScatterSeries("散", [Point(1, 2), Point(3, 4)])])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['柱', '线', '面', '横', '饼一', '饼二', '雷达', '径一', '径二', '堆一', '75.0%', '堆二', '25.0%', '散']) {
      expect(find.text(text), findsWidgets);
    }
  });

  testWidgets('radar chart with an empty series renders without crashing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIStandardLibrary(),
            response: '''
root = RadarChart(["一", "二"], [])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The bordered empty box, not a crash.
    expect(find.byType(RadarChartWidget), findsOneWidget);
  });

  testWidgets('radar chart honours a custom theme palette', (tester) async {
    final controller = OpenUIController(
      library: openUIStandardLibrary(),
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
