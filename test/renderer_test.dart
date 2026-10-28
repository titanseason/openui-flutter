import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

void main() {
  testWidgets('renders card header, chart and button; button dispatches action', (tester) async {
    ActionEvent? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OpenUIRenderer(
              library: openUIMvpLibrary(),
              response: '''
root = Stack([header, chart, cta])
header = CardHeader("Q1 收入", "全部业务线")
chart = BarChart(months, [rev])
months = ["1月", "2月"]
rev = Series("收入", [120, 145])
cta = Button("查看明细", @ToAssistant("查看明细"))
''',
              onAction: (e) => seen = e,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Q1 收入'), findsOneWidget);
    expect(find.text('查看明细'), findsOneWidget);
    await tester.tap(find.text('查看明细'));
    expect(seen?.type, 'toAssistant');
    expect(seen?.args.first, '查看明细');
  });

  testWidgets('tabs keep labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenUIRenderer(
            library: openUIMvpLibrary(),
            response: '''
root = Tabs([t1, t2])
t1 = TabItem("概览", [TextContent("概览内容")])
t2 = TabItem("明细", [TextContent("明细内容")])
''',
          ),
        ),
      ),
    );
    expect(find.text('概览'), findsWidgets);
    expect(find.text('明细'), findsWidgets);
  });
}
