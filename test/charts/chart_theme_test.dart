import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

void main() {
  test('ChartColors defaults reproduce the previously hardcoded greys', () {
    const colors = ChartColors();
    expect(colors.axisText, const Color(0xFF9E9E9E)); // was Colors.grey
    expect(colors.grid, const Color(0xFFEEEEEE)); // was grey.shade200
    expect(colors.border, const Color(0xFFE0E0E0)); // was grey.shade300
  });

  test('light scheme defaults equal the old hardcoded colours', () {
    final scheme = OpenUIThemeData.light().colors;
    expect(scheme.textMuted, const Color(0xFF9E9E9E));
    expect(scheme.border, const Color(0xFFE0E0E0));
    expect(scheme.grid, const Color(0xFFEEEEEE));
    expect(scheme.success, Colors.green);
    expect(scheme.warning, Colors.orange);
    expect(scheme.danger, Colors.red);
    expect(scheme.info, Colors.blue);
  });

  test('dark scheme chrome is lighter than the light defaults', () {
    final scheme = OpenUIThemeData.dark().colors;
    expect(scheme.textMuted, const Color(0xFFBDBDBD));
    expect(scheme.border, const Color(0xFF424242));
    expect(scheme.grid, const Color(0xFF303030));
    expect(scheme.success, Colors.lightGreen);
    expect(scheme.danger, Colors.redAccent);
    expect(scheme.info, Colors.lightBlue);
  });

  test('custom scheme values round-trip', () {
    const scheme = OpenUIColorScheme(
      primary: Colors.purple,
      surface: Colors.white,
      onSurface: Colors.black,
      textMuted: Colors.pink,
      border: Colors.teal,
      grid: Colors.amber,
      success: Colors.lime,
      warning: Colors.cyan,
      danger: Colors.brown,
      info: Colors.indigo,
    );
    expect(scheme.textMuted, Colors.pink);
    expect(scheme.border, Colors.teal);
    expect(scheme.grid, Colors.amber);
    expect(scheme.success, Colors.lime);
    expect(scheme.warning, Colors.cyan);
    expect(scheme.danger, Colors.brown);
    expect(scheme.info, Colors.indigo);
  });

  testWidgets('custom theme reaches the chart box border', (tester) async {
    final controller = OpenUIController(
      library: openUIStandardLibrary(),
      theme: OpenUIThemeData(
        colors: const OpenUIColorScheme(primary: Colors.blue, surface: Colors.white, onSurface: Colors.black, border: Colors.purple),
        chartPalette: OpenUIThemeData.light().chartPalette,
      ),
    );
    controller.push('root = BarChart(["A", "B"], [s])\ns = Series("V", [10, 20])');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: OpenUIRenderer(library: controller.library, controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final borders = tester.widgetList<Container>(find.byType(Container)).where((c) {
      final d = c.decoration;
      return d is BoxDecoration && d.border is Border && (d.border as Border).left.color == Colors.purple;
    });
    expect(borders, isNotEmpty);
    controller.dispose();
  });

  testWidgets('custom theme reaches the Callout variant colour', (tester) async {
    final controller = OpenUIController(
      library: openUIStandardLibrary(),
      theme: OpenUIThemeData(
        colors: const OpenUIColorScheme(primary: Colors.blue, surface: Colors.white, onSurface: Colors.black, success: Colors.pink),
        chartPalette: OpenUIThemeData.light().chartPalette,
      ),
    );
    controller.push('root = Callout("success", "Done", "All good")');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenUIRenderer(library: controller.library, controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fills = tester.widgetList<Container>(find.byType(Container)).where((c) {
      final d = c.decoration;
      return d is BoxDecoration && d.color == Colors.pink.withValues(alpha: 0.08);
    });
    expect(fills, isNotEmpty);
    controller.dispose();
  });

  testWidgets('golden: dark theme bar chart', (tester) async {
    final controller = OpenUIController(library: openUIStandardLibrary(), theme: OpenUIThemeData.dark());
    controller.push('root = BarChart(["周一", "周二", "周三"], [s])\ns = Series("气温", [22, 24, 21])');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: OpenUIRenderer(library: controller.library, controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/chart_bar_dark.png'),
    );
    controller.dispose();
  });
}
