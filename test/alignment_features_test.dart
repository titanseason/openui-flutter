import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

// React 0.18.1 full alignment (general library), feature completion:
// DatePicker range mode, Tag/ChipItem Icon-node refs, and the Pie
// Slice legacy fallback for charts without a values array.

Future<void> _pump(tester, String response) async {
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
  testWidgets('DatePicker range shows from → to; empty range shows 未选择', (tester) async {
    await _pump(tester, 'root = Stack([DatePicker("d", "range", null, {"from": "2026-01-05", "to": "2026-01-12"}), DatePicker("e", "range")])\n');
    expect(find.text('2026-01-05 → 2026-01-12'), findsOneWidget);
    expect(find.text('未选择'), findsOneWidget);
    expect(find.text('选择日期范围'), findsNWidgets(2));
  });

  testWidgets('DatePicker single mode still shows the single date', (tester) async {
    await _pump(tester, 'root = Stack([DatePicker("d", "single", null, "2026-01-05")])\n');
    expect(find.text('2026-01-05'), findsOneWidget);
  });

  testWidgets('Tag icon accepts an Icon node and a string name', (tester) async {
    await _pump(tester, 'root = Stack([Tag("新", Icon("no-such", "finance")), Tag("旧", "search")])\n');
    expect(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.attach_money), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.search), findsOneWidget);
  });

  testWidgets('ChipItem icon accepts an Icon node', (tester) async {
    await _pump(tester, 'root = Stack([Chips("c", "multiple", [ChipItem("a", "A", Icon("no-such", "finance"))])])\n');
    expect(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.attach_money), findsOneWidget);
  });

  testWidgets('Radial and SingleStackedBar read Slice nodes without values', (tester) async {
    await _pump(
      tester,
      'root = Stack([RadialChart([Slice("Alpha", 30), Slice("Beta", 70)]), SingleStackedBarChart([Slice("Alpha", 30), Slice("Beta", 70)])])\n',
    );
    expect(find.textContaining('Alpha'), findsNWidgets(2));
    expect(find.textContaining('Beta'), findsNWidgets(2));
  });
}
