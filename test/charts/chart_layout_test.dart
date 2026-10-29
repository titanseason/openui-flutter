import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

const _cats = '["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"]';
const _vals = '[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]';

Future<void> _pump(WidgetTester tester, String program) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: OpenUIRenderer(
            library: openUIStandardLibrary(),
            response: program,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('condensed chart shows no scroll buttons', (tester) async {
    await _pump(tester, 'root = BarChart($_cats, [s], "grouped", null, null, 220, "default", true, "singleLine")\ns = Series("S", $_vals)\n');
    expect(find.widgetWithIcon(IconButton, Icons.chevron_left), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.chevron_right), findsNothing);
  });

  testWidgets('scroll chart shows scroll buttons for the same data', (tester) async {
    await _pump(tester, 'root = BarChart($_cats, [s])\ns = Series("S", $_vals)\n');
    expect(find.widgetWithIcon(IconButton, Icons.chevron_left), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.chevron_right), findsOneWidget);
  });
}
