import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

void main() {
  test('theme light/dark defaults differ and effectiveTheme falls back to light', () {
    expect(OpenUIThemeData.light().colors.surface, Colors.white);
    expect(OpenUIThemeData.dark().colors.surface, isNot(Colors.white));
    expect(OpenUIThemeData.light().cardRadius, 12);
    final controller = OpenUIController(library: openUIMvpLibrary());
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
    final defaultController = OpenUIController(library: openUIMvpLibrary());
    defaultController.push(program);
    defaultController.finish();
    final redController = OpenUIController(
      library: openUIMvpLibrary(),
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
    final controller = OpenUIController(library: openUIMvpLibrary());
    controller.push('''
root = Stack([chips])
chips = Chips([ChipItem("北京", "beijing"), ChipItem("上海", "shanghai")], "city")
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
    expect(controller.formState['city'], 'shanghai');
    controller.dispose();
  });

  test('controller emits a Query error on its error stream', () async {
    final controller = OpenUIController(
      library: openUIMvpLibrary(),
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
      library: openUIMvpLibrary(),
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
      library: openUIMvpLibrary(),
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
    final controller = OpenUIController(library: openUIMvpLibrary());
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
    final controller = OpenUIController(library: openUIMvpLibrary());
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
}
