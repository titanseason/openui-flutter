import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_lang/openui_lang.dart';

void main() {
  test('runAction after dispose does not throw on closed streams', () async {
    final controller = OpenUIController(library: openUIStandardLibrary());
    controller.dispose();
    // Must return without touching the closed broadcast streams.
    expect(await controller.runAction(const ActionValue('ToAssistant', ['hi'])), isTrue);
  });

  test('theme light/dark defaults differ and effectiveTheme falls back to light', () {
    expect(OpenUIThemeData.light().colors.surface, Colors.white);
    expect(OpenUIThemeData.dark().colors.surface, isNot(Colors.white));
    expect(OpenUIThemeData.light().cardRadius, 12);
    final controller = OpenUIController(library: openUIStandardLibrary());
    expect(controller.effectiveTheme.colors.surface, OpenUIThemeData.light().colors.surface);
    expect(controller.effectiveTheme.chartPalette, OpenUIThemeData.light().chartPalette);
    controller.dispose();
  });

  testWidgets('controller theme changes chart palette without changing data', (tester) async {
    const program = '''
root = BarChart(months, [rev])
months = ["1月", "2月"]
rev = Series("收入", [120, 145])
''';
    final defaultController = OpenUIController(library: openUIStandardLibrary());
    defaultController.push(program);
    defaultController.finish();
    final redController = OpenUIController(
      library: openUIStandardLibrary(),
      theme: OpenUIThemeData(
        colors: OpenUIThemeData.light().colors,
        chartPalette: const [Colors.red, Colors.red],
      ),
    );
    redController.push(program);
    redController.finish();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              OpenUIRenderer(library: defaultController.library, controller: defaultController),
              OpenUIRenderer(library: redController.library, controller: redController),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Same data in both: the series label appears twice.
    expect(find.text('收入'), findsNWidgets(2));
    // The custom palette reaches the chart legend swatch.
    expect(
      find.byWidgetPredicate((w) => w is Container && w.color == Colors.red),
      findsOneWidget,
    );
    defaultController.dispose();
    redController.dispose();
  });

  testWidgets("controller's formState updates after tapping a bound Chips item", (tester) async {
    final controller = OpenUIController(library: openUIStandardLibrary());
    controller.push('''
root = Stack([chips])
chips = Chips("city", "multiple", [ChipItem("beijing", "北京"), ChipItem("shanghai", "上海")])
''');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OpenUIRenderer(library: controller.library, controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('上海'));
    await tester.pumpAndSettle();
    // Chips defaults to multiple: state is a list of selected values.
    expect(controller.formState['city'], ['shanghai']);
    controller.dispose();
  });

  test('controller emits a Query error on its error stream', () async {
    final controller = OpenUIController(
      library: openUIStandardLibrary(),
      toolProvider: (tool, params) async => throw StateError('boom'),
    );
    final firstError = controller.onError.first;
    controller.push('''
root = TextContent("" + @Count(tickets.rows))
tickets = Query("list_tickets", {})
''');
    controller.finish();
    final error = await firstError;
    expect(error, isA<OpenUIError>());
    expect(error.message, contains('list_tickets'));
    controller.dispose();
  });

  testWidgets('controller mode uses the theme skeleton builder while a Query loads', (tester) async {
    final completer = Completer<Object?>();
    final controller = OpenUIController(
      library: openUIStandardLibrary(),
      toolProvider: (tool, params) => completer.future,
      theme: OpenUIThemeData(
        colors: OpenUIThemeData.light().colors,
        chartPalette: OpenUIThemeData.light().chartPalette,
        skeletonBuilder: (context) => const Text('my-skeleton'),
      ),
    );
    controller.push('''
root = TextContent("" + @Count(tickets.rows))
tickets = Query("list_tickets", {})
''');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OpenUIRenderer(library: controller.library, controller: controller)),
      ),
    );
    await tester.pump();
    expect(find.text('my-skeleton'), findsOneWidget);
    completer.complete({'rows': []});
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('controller mode uses the theme error builder for an empty response', (tester) async {
    final controller = OpenUIController(
      library: openUIStandardLibrary(),
      theme: OpenUIThemeData(
        colors: OpenUIThemeData.light().colors,
        chartPalette: OpenUIThemeData.light().chartPalette,
        errorBuilder: (context, error) => Text('custom-error:${error.code}'),
      ),
    );
    controller.push('');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OpenUIRenderer(library: controller.library, controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('custom-error:no-root'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('controller streaming disables Button', (tester) async {
    final events = <ActionEvent>[];
    final controller = OpenUIController(library: openUIStandardLibrary());
    controller.onAction.listen(events.add);
    controller.push('root = Button("点我", Action([@ToAssistant("hi")]))');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OpenUIRenderer(library: controller.library, controller: controller)),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('点我'));
    await tester.pump();
    expect(events, isEmpty);
    controller.dispose();
  });

  testWidgets('controller mode wins over the old response parameter', (tester) async {
    final controller = OpenUIController(library: openUIStandardLibrary());
    controller.push('root = TextContent("控制器内容")');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenUIRenderer(
            library: controller.library,
            controller: controller,
            response: 'root = TextContent("旧参数内容")',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('控制器内容'), findsOneWidget);
    expect(find.text('旧参数内容'), findsNothing);
    controller.dispose();
  });

  testWidgets('typing into a bound Input in controller mode updates controller.formState and a \$variable display', (tester) async {
    final controller = OpenUIController(library: openUIStandardLibrary());
    controller.push('''
root = Stack([inp, show])
inp = Input("city")
show = TextContent("city=" + \$city)
''');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OpenUIRenderer(library: controller.library, controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'shanghai');
    await tester.pumpAndSettle();
    expect(controller.formState['city'], 'shanghai');
    expect(find.text('city=shanghai'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('typing into a bound TextArea in controller mode updates controller.formState and a \$variable display', (tester) async {
    final controller = OpenUIController(library: openUIStandardLibrary());
    controller.push('''
root = Stack([area, show])
area = TextArea("note")
show = TextContent("note=" + \$note)
''');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OpenUIRenderer(library: controller.library, controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'hello');
    await tester.pumpAndSettle();
    expect(controller.formState['note'], 'hello');
    expect(find.text('note=hello'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('controller mode: a failed Query is not retried on rebuild, but an explicit @Run retries it', (tester) async {
    var calls = 0;
    final controller = OpenUIController(
      library: openUIStandardLibrary(),
      toolProvider: (tool, params) async {
        calls++;
        if (calls == 1) throw StateError('boom');
        return {'rows': [1, 2]};
      },
    );
    controller.push('''
root = Stack([count, btn])
count = TextContent("" + @Count(tickets.rows))
tickets = Query("list_tickets", {})
btn = Button("重试", Action([@Run(tickets)]))
''');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OpenUIRenderer(library: controller.library, controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('2'), findsNothing);
    // Rebuilds alone must not retry the failed fetch.
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('2'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('controller mode: a failed Mutation stops the rest of an action list', (tester) async {
    final events = <ActionEvent>[];
    final controller = OpenUIController(
      library: openUIStandardLibrary(),
      toolProvider: (tool, params) async => throw StateError('boom'),
    );
    controller.onAction.listen(events.add);
    controller.push('''
root = Stack([btn])
btn = Button("提交", Action([@Run(bad), @ToAssistant("after")]))
bad = Mutation("bad_mut", {})
''');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OpenUIRenderer(library: controller.library, controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();
    expect(events.map((e) => e.type), contains('mutationError'));
    expect(events.map((e) => e.type), isNot(contains('toAssistant')));
    controller.dispose();
  });

  testWidgets('controller mode: a successful Mutation refetches all queries', (tester) async {
    var queryCalls = 0;
    var mutationCalls = 0;
    final events = <ActionEvent>[];
    final controller = OpenUIController(
      library: openUIStandardLibrary(),
      toolProvider: (tool, params) async {
        if (tool == 'list_tickets') {
          queryCalls++;
          return {'rows': [1]};
        }
        if (tool == 'retry') {
          mutationCalls++;
          return {'ok': true};
        }
        return null;
      },
    );
    controller.onAction.listen(events.add);
    controller.push('''
root = Stack([count, btn])
count = TextContent("" + @Count(tickets.rows))
tickets = Query("list_tickets", {}, {"rows": []})
btn = Button("重试", Action([@Run(retry)]))
retry = Mutation("retry", {})
''');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OpenUIRenderer(library: controller.library, controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(queryCalls, 1);
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(mutationCalls, 1);
    expect(queryCalls, 2);
    expect(events.map((e) => e.type), contains('mutationResult'));
    controller.dispose();
  });
}
