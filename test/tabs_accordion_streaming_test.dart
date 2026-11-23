import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_lang/openui_lang.dart';

// Mirrors the React 0.18.10 Tabs.test.tsx (PR #820, issue #819) and
// Accordion.test.tsx + Accordion.ssr.test.tsx (PR #862, issue #861)
// cases, driven through the renderer's controller streaming plumbing.
void main() {
  Future<void> pumpController(WidgetTester tester, OpenUIController controller) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OpenUIRenderer(library: controller.library, controller: controller)),
      ),
    );
    await tester.pump();
  }

  List<bool> accordionExpanded(WidgetTester tester) {
    return tester
        .widgetList<ExpansionTile>(find.byType(ExpansionTile))
        .map((tile) => tile.initiallyExpanded)
        .toList();
  }

  group('Tabs (React 0.18.10 #820)', () {
    testWidgets('selects the first tab when the whole program renders at once', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpenUIRenderer(
              library: openUIStandardLibrary(),
              response: '''
root = Tabs([t1, t2])
t1 = TabItem("one", "一", [TextContent("内容一")])
t2 = TabItem("two", "二", [TextContent("内容二")])
''',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('内容一').hitTestable(), findsOneWidget);
      expect(find.text('内容二').hitTestable(), findsNothing);
    });

    testWidgets('selects the first tab when a stream delivers every tab in one chunk', (tester) async {
      final controller = OpenUIController(library: openUIStandardLibrary());
      controller.push('''
root = Tabs([t1, t2])
t1 = TabItem("one", "一", [TextContent("内容一")])
t2 = TabItem("two", "二", [TextContent("内容二")])
''');
      await pumpController(tester, controller);
      expect(find.text('内容一').hitTestable(), findsOneWidget);
      expect(find.text('内容二').hitTestable(), findsNothing);
      controller.dispose();
    });

    testWidgets('follows the tab the model is writing into while streaming', (tester) async {
      final controller = OpenUIController(library: openUIStandardLibrary());
      controller.push('''
root = Tabs([t1, t2])
t1 = TabItem("one", "一", [TextContent("内容一")])
t2 = TabItem("two", "二", [TextContent("内容二")])
''');
      await pumpController(tester, controller);
      expect(find.text('内容一').hitTestable(), findsOneWidget);

      controller.push('''
t3 = TabItem("three", "三", [TextContent("内容三")])
root = Tabs([t1, t2, t3])
''');
      await tester.pumpAndSettle();
      expect(find.text('内容三').hitTestable(), findsOneWidget);
      expect(find.text('内容一').hitTestable(), findsNothing);
      controller.dispose();
    });

    testWidgets('stays put when another tab grows after streaming ends', (tester) async {
      final queryResult = Completer<Object?>();
      final controller = OpenUIController(
        library: openUIStandardLibrary(),
        toolProvider: (tool, params) => queryResult.future,
      );
      controller.push('''
root = Tabs([t1, t2])
t1 = TabItem("one", "一", [TextContent("内容一")])
t2 = TabItem("two", "二", [TextContent("" + @Count(q.rows))])
q = Query("get_rows", {}, {"rows": []})
''');
      await pumpController(tester, controller);
      expect(find.text('内容一').hitTestable(), findsOneWidget);
      expect(find.text('0').hitTestable(), findsNothing);

      // Streaming ends first; only then does the Query resolve and
      // grow the second tab's content.
      controller.finish();
      await tester.pump();
      queryResult.complete({
        'rows': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      });
      await tester.pumpAndSettle();
      expect(find.text('内容一').hitTestable(), findsOneWidget);
      // The growth really landed: switching to the second tab shows it.
      await tester.tap(find.text('二'));
      await tester.pumpAndSettle();
      expect(find.text('10').hitTestable(), findsOneWidget);
      controller.dispose();
    });

    testWidgets('a user tap overrides auto-follow while streaming', (tester) async {
      final controller = OpenUIController(library: openUIStandardLibrary());
      controller.push('''
root = Tabs([t1, t2])
t1 = TabItem("one", "一", [TextContent("内容一")])
t2 = TabItem("two", "二", [TextContent("内容二")])
''');
      await pumpController(tester, controller);
      await tester.tap(find.text('二'));
      await tester.pumpAndSettle();
      expect(find.text('内容二').hitTestable(), findsOneWidget);

      controller.push('''
t3 = TabItem("three", "三", [TextContent("内容三")])
root = Tabs([t1, t2, t3])
''');
      await tester.pumpAndSettle();
      expect(find.text('内容二').hitTestable(), findsOneWidget);
      expect(find.text('内容三').hitTestable(), findsNothing);
      controller.dispose();
    });
  });

  group('Accordion (React 0.18.10 #862)', () {
    testWidgets('opens the first item when it mounts with every item present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpenUIRenderer(
              library: openUIStandardLibrary(),
              response: '''
root = Accordion([a1, a2])
a1 = AccordionItem("apple", "Apple", [TextContent("Apple content")])
a2 = AccordionItem("banana", "Banana", [TextContent("Banana content")])
''',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Apple content'), findsOneWidget);
      expect(find.text('Banana content'), findsNothing);
    });

    testWidgets('opens the newest item as items stream in', (tester) async {
      final controller = OpenUIController(library: openUIStandardLibrary());
      await pumpController(tester, controller);
      controller.push('root = Accordion([])\n');
      await tester.pump();
      controller.push('''
a1 = AccordionItem("apple", "Apple", [TextContent("Apple content")])
root = Accordion([a1])
''');
      await tester.pump();
      expect(find.text('Apple content'), findsOneWidget);

      controller.push('''
a2 = AccordionItem("banana", "Banana", [TextContent("Banana content")])
root = Accordion([a1, a2])
''');
      await tester.pumpAndSettle();
      expect(find.text('Banana content'), findsOneWidget);
      expect(find.text('Apple content'), findsNothing);
      expect(accordionExpanded(tester), [false, true]);
      controller.dispose();
    });

    testWidgets('keeps the newest item open while its value is still streaming in', (tester) async {
      final controller = OpenUIController(library: openUIStandardLibrary());
      await pumpController(tester, controller);
      controller.push('''
a1 = AccordionItem("apple", "Apple", [TextContent("Apple content")])
root = Accordion([a1])
''');
      await tester.pump();
      controller.push('''
a2 = AccordionItem("ba", "Banana", [TextContent("Banana content")])
root = Accordion([a1, a2])
''');
      await tester.pump();
      expect(find.text('Banana content'), findsOneWidget);

      // Only the value streams in; the item count is unchanged.
      controller.push('a2 = AccordionItem("banana", "Banana", [TextContent("Banana content")])\n');
      await tester.pumpAndSettle();
      expect(find.text('Banana content'), findsOneWidget);
      expect(find.text('Apple content'), findsNothing);
      expect(accordionExpanded(tester), [false, true]);
      controller.dispose();
    });

    testWidgets('a static mount opens only the first section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpenUIRenderer(
              library: openUIStandardLibrary(),
              response: '''
root = Accordion([a1, a2, a3])
a1 = AccordionItem("one", "第一节", [TextContent("内容一")])
a2 = AccordionItem("two", "第二节", [TextContent("内容二")])
a3 = AccordionItem("three", "第三节", [TextContent("内容三")])
''',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(accordionExpanded(tester), [true, false, false]);
      expect(find.text('内容一'), findsOneWidget);
      expect(find.text('内容二'), findsNothing);
      expect(find.text('内容三'), findsNothing);
    });

    testWidgets('a user tap overrides auto-open as items stream in', (tester) async {
      final controller = OpenUIController(library: openUIStandardLibrary());
      controller.push('''
a1 = AccordionItem("apple", "Apple", [TextContent("Apple content")])
a2 = AccordionItem("banana", "Banana", [TextContent("Banana content")])
root = Accordion([a1, a2])
''');
      await pumpController(tester, controller);
      expect(find.text('Apple content'), findsOneWidget);
      await tester.tap(find.text('Banana'));
      await tester.pumpAndSettle();
      expect(find.text('Banana content'), findsOneWidget);

      controller.push('''
a3 = AccordionItem("cherry", "Cherry", [TextContent("Cherry content")])
root = Accordion([a1, a2, a3])
''');
      await tester.pumpAndSettle();
      expect(find.text('Banana content'), findsOneWidget);
      expect(find.text('Cherry content'), findsNothing);
      expect(accordionExpanded(tester), [false, true, false]);
      controller.dispose();
    });
  });
}
