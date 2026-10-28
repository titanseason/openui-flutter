import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

void main() {
  final library = openUIStandardLibrary();

  testWidgets('Query loads through toolProvider, then renders data', (tester) async {
    final completer = Completer<Object?>();
    Future<Object?> provider(String tool, Map<String, Object?> params) => completer.future;
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = Stack([count])
count = TextContent("" + @Count(tickets.rows))
tickets = Query("list_tickets", {"status": "open"})
''',
          toolProvider: provider,
        ),
      ),
    );
    await tester.pump();
    // Still loading: the count text is a skeleton, not "2".
    expect(find.text('2'), findsNothing);
    completer.complete({
      'rows': [
        {'status': 'open'},
        {'status': 'open'},
      ],
    });
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('@Run on a Mutation calls the tool, then refetches Queries', (tester) async {
    var queryCalls = 0;
    var mutationCalls = 0;
    final events = <ActionEvent>[];
    Future<Object?> provider(String tool, Map<String, Object?> params) async {
      if (tool == 'list_tickets') {
        queryCalls++;
        return {'rows': [1]};
      }
      if (tool == 'retry') {
        mutationCalls++;
        return {'ok': true};
      }
      return null;
    }
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = Stack([count, btn])
count = TextContent("" + @Count(tickets.rows))
tickets = Query("list_tickets", {}, {"rows": []})
btn = Button("重试", Action([@Run(retry)]))
retry = Mutation("retry", {})
''',
          toolProvider: provider,
          onAction: events.add,
        ),
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
  });

  testWidgets('@Run on a Query refetches only that Query', (tester) async {
    var queryCalls = 0;
    Future<Object?> provider(String tool, Map<String, Object?> params) async {
      queryCalls++;
      return {'rows': [1, 2]};
    }
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = Stack([count, btn])
count = TextContent("" + @Count(tickets.rows))
tickets = Query("list_tickets", {}, {"rows": []})
btn = Button("刷新", Action([@Run(tickets)]))
''',
          toolProvider: provider,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(queryCalls, 1);
    await tester.tap(find.text('刷新'));
    await tester.pumpAndSettle();
    expect(queryCalls, 2);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a failed Query calls onToolError', (tester) async {
    String? failedTool;
    Future<Object?> provider(String tool, Map<String, Object?> params) async => throw StateError('boom');
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = TextContent("" + @Count(tickets.rows))
tickets = Query("list_tickets", {})
''',
          toolProvider: provider,
          onToolError: (tool, error) => failedTool = tool,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(failedTool, 'list_tickets');
  });

  testWidgets('streaming disables Button', (tester) async {
    var actions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: 'root = Button("点我", Action([@ToAssistant("hi")]))',
          isStreaming: true,
          onAction: (_) => actions++,
        ),
      ),
    );
    await tester.tap(find.text('点我'));
    await tester.pump();
    expect(actions, 0);
  });
}
