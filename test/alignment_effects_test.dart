import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

// React 0.18.1 full alignment (general library): props that used to
// be accepted with no visible effect now do what React does —
// Icon category fallback, Separator decorative, Point z, EntityList
// rightVariant number, card-block responsive breakpoints, bgImageAlt
// semantics, Select's default "Select..." placeholder.

Future<void> _pump(tester, String response, {double? viewportWidth}) async {
  // Narrow widths must come from the test viewport itself: a
  // SizedBox inside the 800-wide scroll viewport cannot shrink its
  // child below the viewport width (parent constraints win).
  if (viewportWidth != null) {
    tester.view.physicalSize = Size(viewportWidth, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    MaterialApp(
      home: SingleChildScrollView(
        child: OpenUIRenderer(library: openUIStandardLibrary(), response: response),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Icon category falls back when the name misses; kebab names resolve', (tester) async {
    await _pump(tester, 'root = Stack([Icon("no-such-icon", "finance"), Icon("arrow-right"), Icon("search")])\n');
    expect(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.attach_money), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.arrow_forward), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.search), findsOneWidget);
  });

  testWidgets('decorative Separator is excluded from semantics', (tester) async {
    await _pump(tester, 'root = Stack([Separator("horizontal", true), Separator()])\n');
    final dividers = find.byType(Divider);
    expect(dividers, findsNWidgets(2));
    expect(find.ancestor(of: dividers.first, matching: find.byType(ExcludeSemantics)), findsOneWidget);
    expect(find.ancestor(of: dividers.at(1), matching: find.byType(ExcludeSemantics)), findsNothing);
  });

  testWidgets('EntityList rightVariant number uses tabular figures', (tester) async {
    await _pump(
      tester,
      'root = EntityList([{"left": "A", "right": "100", "rightVariant": "number"}, {"left": "B", "right": "text"}])\n',
    );
    bool tabular(Widget w) =>
        w is Text && (w.style?.fontFeatures ?? const []).any((f) => f.feature == 'tnum');
    expect(find.byWidgetPredicate(tabular), findsOneWidget);
  });

  testWidgets('Point z scales scatter bubble radius', (tester) async {
    await _pump(
      tester,
      'root = ScatterChart([ScatterSeries("s", [Point(1, 2, 1), Point(3, 4, 100), Point(5, 6)])])\n',
    );
    final chart = tester.widget<ScatterChartWidget>(find.byType(ScatterChartWidget));
    final radii = computeScatterLayout(chart.series).dots.map((d) => d.radius).toList();
    expect(radii.length, 3);
    expect(radii[0] < radii[1], isTrue, reason: 'z=100 bubble is bigger than z=1');
    expect(radii[2], 6, reason: 'no z keeps the default radius');
  });

  testWidgets('bgImageAlt is the bg image semantic label', (tester) async {
    await _pump(
      tester,
      'root = VisualCardBlock([VisualCardItem(BoldText("text", "体"), null, "https://example.com/bg.png", Tag("标"), "背景说明"), VisualCardItem(BoldText("text", "体二"), null, null, Tag("标二"))])\n',
    );
    expect(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.label == '背景说明'),
      findsOneWidget,
    );
  });

  testWidgets('Select without placeholder shows Select...', (tester) async {
    await _pump(tester, 'root = Stack([Select("x", [SelectItem("a", "A")])])\n');
    expect(find.text('Select...'), findsOneWidget);
  });

  testWidgets('card-block responsive breakpoints and non-responsive rows', (tester) async {
    const program =
        'root = SnippetCardBlock([SnippetCardItem(null, Text("text", "一")), SnippetCardItem(null, Text("text", "二")), SnippetCardItem(null, Text("text", "三")), SnippetCardItem(null, Text("text", "四"))])\n';
    // 300 wide: 1 column Wrap.
    await _pump(tester, program, viewportWidth: 300);
    expect(find.byWidgetPredicate((w) => w is Wrap && w.spacing == 12), findsOneWidget);
    // 800 wide: rows (3 + 1 would be lonely, so React balances 2 + 2).
    await _pump(tester, program, viewportWidth: 800);
    expect(find.byWidgetPredicate((w) => w is Row), findsNWidgets(2));
    // Non-responsive at 500 wide: rows, not the 2-column Wrap.
    await _pump(
      tester,
      'root = SnippetCardBlock([SnippetCardItem(null, Text("text", "一")), SnippetCardItem(null, Text("text", "二"))], "grid", false)\n',
      viewportWidth: 500,
    );
    expect(find.byWidgetPredicate((w) => w is Row), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Wrap && w.spacing == 12), findsNothing);
  });
}
