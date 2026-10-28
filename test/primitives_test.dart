import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

void main() {
  final library = openUIStandardLibrary();

  testWidgets('TableSkeleton shows while a Table Query loads', (tester) async {
    final completer = Completer<Object?>();
    Future<Object?> provider(String tool, Map<String, Object?> params) => completer.future;
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = Table([c])
c = Col("名", tickets.rows)
tickets = Query("list_tickets", {})
''',
          toolProvider: provider,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(TableSkeleton), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('Citation renders [n] and Sources renders titles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Citation(index: 2, title: 'Doc'),
              const Sources(items: [
                (title: 'A', url: null, faviconUrl: null),
                (title: 'B', url: 'https://example.com', faviconUrl: null),
              ]),
            ],
          ),
        ),
      ),
    );
    expect(find.text('[2]'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('Skeleton renders count bars and TableSkeleton renders a grid', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Skeleton(count: 3),
              TableSkeleton(columns: 2, rows: 3),
            ],
          ),
        ),
      ),
    );
    // Skeleton: 3 bars. TableSkeleton: 3 rows x 2 cells = 6 cells.
    // Bars set their colour via decoration (as _Skeleton does), not
    // via Container.color, so the predicate reads the decoration.
    expect(
      find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == Colors.grey.shade300,
      ),
      findsNWidgets(9),
    );
  });

  testWidgets('Citation tap calls onTap and does nothing without it', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Citation(index: 1, title: 'Doc', onTap: () => tapped++),
              const Citation(index: 2, title: 'Other'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('[1]'));
    await tester.pump();
    expect(tapped, 1);
    await tester.tap(find.text('[2]'));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('Sources renders a favicon image when faviconUrl is present', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Sources(items: [
            (title: 'Site', url: 'https://example.com', faviconUrl: 'https://example.com/favicon.png'),
          ]),
        ),
      ),
    );
    expect(find.text('Site'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('Table Query error surfaces error text instead of an empty column', (tester) async {
    Future<Object?> provider(String tool, Map<String, Object?> params) async => throw StateError('boom');
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = Table([c])
c = Col("名", tickets.rows)
tickets = Query("list_tickets", {})
''',
          toolProvider: provider,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('数据加载失败：list_tickets'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('Table Query error uses theme errorBuilder in controller mode', (tester) async {
    final controller = OpenUIController(
      library: openUIStandardLibrary(),
      toolProvider: (tool, params) async => throw StateError('boom'),
      theme: OpenUIThemeData(
        colors: OpenUIThemeData.light().colors,
        chartPalette: OpenUIThemeData.light().chartPalette,
        errorBuilder: (context, error) => const Text('custom-table-error'),
      ),
    );
    controller.push('''
root = Table([c])
c = Col("名", tickets.rows)
tickets = Query("list_tickets", {})
''');
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OpenUIRenderer(library: controller.library, controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('custom-table-error'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    controller.dispose();
  });
}
