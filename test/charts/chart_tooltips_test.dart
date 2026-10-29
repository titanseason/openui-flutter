import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

/// The single paint area of the rendered chart.
({Offset topLeft, Size size}) paintArea(WidgetTester tester) {
  final finder = find.byType(CustomPaint);
  expect(finder, findsOneWidget);
  return (topLeft: tester.getTopLeft(finder), size: tester.getSize(finder));
}

Future<void> pumpChart(WidgetTester tester, String response) async {
  await tester.pumpWidget(
    MaterialApp(
      // The debug banner is itself a CustomPaint; hide it so the
      // chart's paint area is the only one in the tree.
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: OpenUIRenderer(
          library: openUIStandardLibrary(),
          response: response,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A mouse hover at [point]; returns the gesture so the caller can
/// move it again or drop it.
Future<TestGesture> hoverAt(WidgetTester tester, Offset point) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  await gesture.moveTo(point);
  await tester.pump();
  return gesture;
}

String tipTitle(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('chart-tip-title'))).data!;
}

void main() {
  testWidgets('bar tooltip follows mouse hover by category slot', (tester) async {
    await pumpChart(tester, 'root = BarChart(["A", "B"], [Series("S", [10, 20])])');
    final area = paintArea(tester);
    final gesture = await hoverAt(tester, area.topLeft + Offset(area.size.width * 0.75, area.size.height * 0.5));
    expect(find.byKey(const Key('chart-tip-title')), findsOneWidget);
    expect(tipTitle(tester), 'B');
    expect(find.text('S'), findsNWidgets(2));
    expect(find.text('20'), findsOneWidget);
    // Moving into the other slot swaps the tooltip.
    await gesture.moveTo(area.topLeft + Offset(area.size.width * 0.25, area.size.height * 0.5));
    await tester.pump();
    expect(tipTitle(tester), 'A');
    expect(find.text('10'), findsOneWidget);
    await gesture.removePointer();
  });

  testWidgets('horizontal bar tooltip follows the row slot', (tester) async {
    await pumpChart(tester, 'root = HorizontalBarChart(["A", "B"], [Series("S", [10, 20])])');
    final area = paintArea(tester);
    final gesture = await hoverAt(tester, area.topLeft + Offset(area.size.width * 0.5, area.size.height * 0.75));
    expect(tipTitle(tester), 'B');
    expect(find.text('20'), findsOneWidget);
    await gesture.removePointer();
  });

  testWidgets('line tooltip picks the nearest point', (tester) async {
    await pumpChart(tester, 'root = LineChart(["A", "B"], [Series("L", [10, 20])])');
    final area = paintArea(tester);
    final gesture = await hoverAt(tester, area.topLeft + Offset(area.size.width * 0.75, area.size.height * 0.5));
    expect(tipTitle(tester), 'B');
    expect(find.text('20'), findsOneWidget);
    await gesture.removePointer();
  });

  testWidgets('touch drag moves the tooltip, touch end hides it', (tester) async {
    await pumpChart(tester, 'root = BarChart(["A", "B"], [Series("S", [10, 20])])');
    final area = paintArea(tester);
    final gesture = await tester.startGesture(area.topLeft + Offset(area.size.width * 0.25, area.size.height * 0.5));
    // Past the pan slop so the pan recognizer claims the gesture.
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(find.byKey(const Key('chart-tip-title')), findsOneWidget);
    expect(tipTitle(tester), 'A');
    await gesture.up();
    await tester.pump();
    expect(find.byKey(const Key('chart-tip-title')), findsNothing);
  });

  testWidgets('tapping a legend entry hides its series from chart and tooltip', (tester) async {
    await pumpChart(tester, 'root = BarChart(["A", "B"], [Series("S1", [10, 20]), Series("S2", [30, 40])])');
    await tester.tap(find.text('S1'));
    await tester.pump();
    expect(find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.3), findsOneWidget);
    final area = paintArea(tester);
    final gesture = await hoverAt(tester, area.topLeft + Offset(area.size.width * 0.25, area.size.height * 0.5));
    expect(tipTitle(tester), 'A');
    // S1 survives only as the legend row; S2 is in legend + tooltip.
    expect(find.text('S1'), findsOneWidget);
    expect(find.text('S2'), findsNWidgets(2));
    expect(find.text('30'), findsOneWidget);
    expect(find.text('10'), findsNothing);
    // Tapping again restores it.
    await gesture.removePointer();
    await tester.tap(find.text('S1'));
    await tester.pump();
    expect(find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.3), findsNothing);
  });

  testWidgets('pie tooltip follows slices, hiding one re-normalizes the rest', (tester) async {
    await pumpChart(tester, 'root = PieChart(["A", "B"], [1, 1])');
    final area = paintArea(tester);
    final center = area.topLeft + Offset(area.size.width / 2, area.size.height / 2);
    // Top half is slice B (circular starts at 3 o'clock).
    final gesture = await hoverAt(tester, center + const Offset(0, -43));
    expect(tipTitle(tester), 'B');
    // Bottom half is slice A.
    await gesture.moveTo(center + const Offset(0, 43));
    await tester.pump();
    expect(tipTitle(tester), 'A');
    await gesture.removePointer();
    await tester.pump();
    // Hide A: B now covers the whole circle.
    await tester.tap(find.text('A'));
    await tester.pump();
    expect(find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.3), findsOneWidget);
    final gesture2 = await hoverAt(tester, center + const Offset(0, 43));
    expect(tipTitle(tester), 'B');
    await gesture2.removePointer();
  });

  testWidgets('radial tooltip follows rings, hidden rings show nothing', (tester) async {
    await pumpChart(tester, 'root = RadialChart(["R1", "R2"], [3, 1])');
    final area = paintArea(tester);
    final center = area.topLeft + Offset(area.size.width / 2, area.size.height / 2);
    // Outer ring (radius 82) is R1, next ring (66) is R2.
    final gesture = await hoverAt(tester, center + const Offset(82, 0));
    expect(tipTitle(tester), 'R1');
    await gesture.moveTo(center + const Offset(66, 0));
    await tester.pump();
    expect(tipTitle(tester), 'R2');
    await gesture.removePointer();
    await tester.pump();
    await tester.tap(find.text('R1'));
    await tester.pump();
    final gesture2 = await hoverAt(tester, center + const Offset(82, 0));
    expect(find.byKey(const Key('chart-tip-title')), findsNothing);
    await gesture2.removePointer();
  });

  testWidgets('radar tooltip shows the nearest axis values', (tester) async {
    await pumpChart(tester, 'root = RadarChart(["A", "B", "C"], [Series("R", [10, 20, 30])])');
    final area = paintArea(tester);
    final center = area.topLeft + Offset(area.size.width / 2, area.size.height / 2);
    // Axis A points up (-pi/2): hovering above the center hits it.
    final gesture = await hoverAt(tester, center + const Offset(0, -40));
    expect(tipTitle(tester), 'A');
    expect(find.text('10'), findsOneWidget);
    await gesture.removePointer();
  });

  testWidgets('scatter tooltip shows the hovered point', (tester) async {
    await pumpChart(tester, 'root = ScatterChart([ScatterSeries("S", [Point(1, 2), Point(3, 4)])])');
    final area = paintArea(tester);
    // The (3, 4) dot maps to the plot's top-right corner, which no
    // axis inset moves: the right edge stays the right edge and
    // the top stays the top.
    final gesture = await hoverAt(tester, area.topLeft + Offset(area.size.width - 5, 5));
    expect(tipTitle(tester), 'S');
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    await gesture.removePointer();
  });

  testWidgets('negative values show in tooltips and do not crash', (tester) async {
    await pumpChart(tester, 'root = BarChart(["A", "B"], [Series("S", [-10, 20])])');
    var area = paintArea(tester);
    var gesture = await hoverAt(tester, area.topLeft + Offset(area.size.width * 0.25, area.size.height * 0.5));
    expect(tipTitle(tester), 'A');
    expect(find.text('-10'), findsOneWidget);
    await gesture.removePointer();
    await pumpChart(tester, 'root = LineChart(["A", "B"], [Series("L", [-5, 15])])');
    area = paintArea(tester);
    gesture = await hoverAt(tester, area.topLeft + Offset(area.size.width * 0.25, area.size.height * 0.5));
    expect(tipTitle(tester), 'A');
    expect(find.text('-5'), findsOneWidget);
    await gesture.removePointer();
  });

  testWidgets('stacked bars with mixed signs show both segments', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: BarChartWidget(
            categories: ['A'],
            series: [
              ElementNode('Series', {'category': 'P', 'values': [10]}, 's1'),
              ElementNode('Series', {'category': 'N', 'values': [-4]}, 's2'),
            ],
            stacked: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final area = paintArea(tester);
    final gesture = await hoverAt(tester, area.topLeft + Offset(area.size.width * 0.5, area.size.height * 0.5));
    expect(tipTitle(tester), 'A');
    expect(find.text('10'), findsOneWidget);
    expect(find.text('-4'), findsOneWidget);
    await gesture.removePointer();
  });

  testWidgets('stacked tooltip shows value and percentage, legend has no toggle', (tester) async {
    await pumpChart(tester, 'root = SingleStackedBarChart(["A", "B"], [1, 3])');
    final area = paintArea(tester);
    // The horizontal track: segment A is the first quarter, so a
    // point well inside the left quarter hits it.
    final gesture = await hoverAt(tester, area.topLeft + Offset(100, area.size.height / 2));
    expect(tipTitle(tester), 'A');
    expect(find.text('1'), findsOneWidget);
    // Tooltip row and legend row both show 25.0%.
    expect(find.text('25.0%'), findsNWidgets(2));
    await gesture.removePointer();
    await tester.pump();
    // React's SegmentedBar has no legend visibility toggle.
    await tester.tap(find.text('A'));
    await tester.pump();
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('empty categories show no tooltip', (tester) async {
    await pumpChart(tester, 'root = BarChart([], [Series("S", [])])');
    final area = paintArea(tester);
    final gesture = await hoverAt(tester, area.topLeft + Offset(area.size.width / 2, area.size.height / 2));
    expect(find.byKey(const Key('chart-tip-title')), findsNothing);
    await gesture.removePointer();
  });

  testWidgets('series legend collapses behind N more and expands', (tester) async {
    await pumpChart(
      tester,
      'root = BarChart(["A"], [Series("AlphaSeriesNameOne", [1]), Series("BetaSeriesNameTwo", [2]), Series("GammaSeriesNameThree", [3]), Series("DeltaSeriesNameFour", [4]), Series("EpsilonSeriesNameFive", [5])])',
    );
    // Five long names cannot fit one 800px row: a "N more" button
    // appears (the exact count depends on the test font, so only
    // the shape is pinned).
    expect(find.textContaining(RegExp(r'^\d+ more$')), findsOneWidget);
    expect(find.text('EpsilonSeriesNameFive'), findsNothing);
    await tester.tap(find.textContaining(RegExp(r'^\d+ more$')));
    await tester.pump();
    expect(find.text('Show Less'), findsOneWidget);
    expect(find.text('EpsilonSeriesNameFive'), findsOneWidget);
  });

  testWidgets('stacked legend shows 6 rows then Show more', (tester) async {
    await pumpChart(tester, 'root = PieChart(["P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8"], [1, 1, 1, 1, 1, 1, 1, 1])');
    expect(find.text('P6'), findsOneWidget);
    expect(find.text('P7'), findsNothing);
    expect(find.text('Show more'), findsOneWidget);
    await tester.tap(find.text('Show more'));
    await tester.pump();
    expect(find.text('P7'), findsOneWidget);
    expect(find.text('P8'), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('stacked legend percentages re-normalize over visible slices', (tester) async {
    await pumpChart(tester, 'root = PieChart(["A", "B"], [1, 3])');
    expect(find.text('25.0%'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);
    await tester.tap(find.text('A'));
    await tester.pump();
    // Only B is visible now, so it is 100% of the visible total.
    expect(find.text('100.0%'), findsOneWidget);
  });
}
