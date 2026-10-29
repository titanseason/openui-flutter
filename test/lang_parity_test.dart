import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

void main() {
  final library = openUIStandardLibrary();

  testWidgets('failed Query shows error view and @Run retries it', (tester) async {
    var calls = 0;
    var toolErrors = 0;
    Future<Object?> provider(String tool, Map<String, Object?> params) async {
      calls++;
      if (calls == 1) throw StateError('boom');
      return {'rows': [1, 2]};
    }
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = Stack([count, btn])
count = TextContent("" + @Count(tickets.rows))
tickets = Query("list_tickets", {})
btn = Button("重试", Action([@Run(tickets)]))
''',
          toolProvider: provider,
          onToolError: (tool, error) => toolErrors++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('数据加载失败：list_tickets'), findsOneWidget);
    expect(toolErrors, 1);
    expect(calls, 1);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('failed Query in controller mode renders theme errorBuilder', (tester) async {
    Future<Object?> provider(String tool, Map<String, Object?> params) async => throw StateError('boom');
    final theme = OpenUIThemeData(
      colors: OpenUIThemeData.light().colors,
      chartPalette: OpenUIThemeData.light().chartPalette,
      errorBuilder: (context, error) => Text('custom-error:${error.code}'),
    );
    final controller = OpenUIController(library: library, toolProvider: provider, theme: theme);
    addTearDown(controller.dispose);
    controller.push('''
root = TextContent("" + @Count(tickets.rows))
tickets = Query("list_tickets", {})
''');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(home: OpenUIRenderer(library: library, controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('custom-error:tool-error'), findsOneWidget);
  });

  testWidgets('Modal opens as a dialog and does not reopen after close', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = Stack([m])
m = Modal("标题", true, [TextContent("弹窗内容")])
''',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('弹窗内容'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('replacement Modal at same position opens after first is closed', (tester) async {
    Widget widgetFor(String response) => MaterialApp(
      home: OpenUIRenderer(library: library, response: response),
    );
    await tester.pumpWidget(
      widgetFor('''
root = Stack([m])
m = Modal("标题一", true, [TextContent("内容一")])
'''),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('内容一'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    // A different Modal statement at the same position (same Stack
    // child slot, so Flutter reuses the _ModalWidget state) must open
    // again; the first statement's dismissed flag must not block it.
    await tester.pumpWidget(
      widgetFor('''
root = Stack([m2])
m2 = Modal("标题二", true, [TextContent("内容二")])
'''),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('内容二'), findsOneWidget);
  });

  testWidgets('EditableTable cell edits + Save Changes write rows under name', (tester) async {
    final states = <Map<String, Object?>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = Stack([t])
t = EditableTable("staff", [{"type": "text", "key": "name", "header": "姓名"}, {"type": "number", "key": "age", "header": "年龄"}], [{"id": "r1", "values": ["a", 30]}])
''',
          onStateUpdate: states.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'zhang');
    await tester.pump();
    expect(states.last['staff:r1:name'], 'zhang');
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(states.last['staff'], equals([
      {'id': 'r1', 'values': ['zhang', 30]},
    ]));
  });

  testWidgets('EditableTable without name keys cells by statement and Save writes nothing', (tester) async {
    final states = <Map<String, Object?>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = Stack([t])
t = EditableTable(null, [{"type": "text", "key": "name", "header": "姓名"}], [{"id": "r1", "values": ["a"]}])
''',
          onStateUpdate: states.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'zhang');
    await tester.pump();
    expect(states.last['t:r1:name'], 'zhang');
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(states.every((s) => !s.containsKey('')), isTrue);
  });

  testWidgets('parse callbacks fire once when streaming ends, not per frame', (tester) async {
    var parseResults = 0;
    var parseErrors = 0;
    final widget = OpenUIRenderer(
      library: library,
      response: 'root = Stack([Nope("x")])',
      isStreaming: true,
      onParseResult: (errors) => parseResults++,
      onError: (error) => parseErrors++,
    );
    await tester.pumpWidget(MaterialApp(home: widget));
    await tester.pump();
    expect(parseResults, 0);
    expect(parseErrors, 0);
    // Streaming ends: same response, isStreaming false.
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: 'root = Stack([Nope("x")])',
          isStreaming: false,
          onParseResult: (errors) => parseResults++,
          onError: (error) => parseErrors++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(parseResults, 1);
    expect(parseErrors, 1);
    await tester.pump();
    expect(parseResults, 1);
    expect(parseErrors, 1);
  });

  testWidgets('parse callbacks fire once for a non-streaming response', (tester) async {
    var parseResults = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: 'root = TextContent("hi")',
          onParseResult: (errors) => parseResults++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(parseResults, 1);
    await tester.pump();
    expect(parseResults, 1);
  });
}
