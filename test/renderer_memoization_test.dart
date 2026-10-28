import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

// Renderer-side incrementality: the incremental parser returns the
// same ElementNode objects for unchanged statements, and _buildNode
// caches pure subtrees by node identity. Rebuilding with the same
// (or partly changed) program must return identical Widget objects
// for the unchanged leaves — Flutter's element update then skips
// those subtrees entirely — while state-reading subtrees rebuild.

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
  testWidgets('rebuilding the same program reuses identical leaf widgets', (tester) async {
    const program = 'a = Text("text", "甲")\nb = Text("text", "乙")\nroot = Stack([a, b])\n';
    await _pump(tester, program);
    final first = tester.widget<Text>(find.text('甲'));
    await _pump(tester, program);
    final second = tester.widget<Text>(find.text('甲'));
    expect(identical(first, second), isTrue);
  });

  testWidgets('changing one statement rebuilds only its subtree', (tester) async {
    await _pump(tester, 'a = Text("text", "甲")\nb = Text("text", "乙")\nroot = Stack([a, b])\n');
    final before = tester.widget<Text>(find.text('甲'));
    await _pump(tester, 'a = Text("text", "甲")\nb = Text("text", "丙")\nroot = Stack([a, b])\n');
    expect(find.text('乙'), findsNothing);
    expect(find.text('丙'), findsOneWidget);
    expect(identical(before, tester.widget<Text>(find.text('甲'))), isTrue);
  });

  testWidgets('appending a statement keeps earlier leaves identical (streaming)', (tester) async {
    await _pump(tester, 'a = Text("text", "甲")\nroot = Stack([a])\n');
    final before = tester.widget<Text>(find.text('甲'));
    await _pump(tester, 'a = Text("text", "甲")\nb = Text("text", "乙")\nroot = Stack([a, b])\n');
    expect(find.text('乙'), findsOneWidget);
    expect(identical(before, tester.widget<Text>(find.text('甲'))), isTrue);
  });

  testWidgets('typing in a form field still renders everything (no identity)', (tester) async {
    // No identity assertion here: the parser re-evaluates every
    // statement when form state changes (invalidateAll), so a form
    // edit legitimately produces new node objects and new widgets.
    // Memoization's win is streaming appends and host rebuilds.
    await _pump(tester, 'q = Input("name")\nt = Text("text", "纯")\nroot = Stack([q, t])\n');
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('纯'), findsOneWidget);
  });

  testWidgets('carousel builds distant slides on demand', (tester) async {
    // Slides hold TextContent: bare Text is not in React's content
    // child union, so the mapper would empty Text slides. Only the
    // current page is built at first; each swipe builds the next.
    await _pump(
      tester,
      'root = Carousel([[TextContent("一")], [TextContent("二")], [TextContent("三")]])\n',
    );
    expect(find.text('一'), findsOneWidget);
    expect(find.text('二'), findsNothing);
    expect(find.text('三'), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(-800, 0));
    await tester.pumpAndSettle();
    expect(find.text('二'), findsOneWidget);
    expect(find.text('三'), findsNothing);
    await tester.fling(find.byType(PageView), const Offset(-800, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('三'), findsOneWidget);
  });
}
