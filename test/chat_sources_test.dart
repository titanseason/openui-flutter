import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

// Chat Card sources: the strip below the card and inline [n]
// citations in TextContent, backed by the enclosing Card's sources.
void main() {
  const program = '''
root = Card([t], [{"title": "官方文档", "sourceName": "OpenUI", "url": "https://example.com/docs"}, {"title": "博客文章", "url": "https://example.com/blog"}])
t = TextContent("结论见[1]和[2]，未引用[9]。")
''';

  testWidgets('sources render as a strip below the card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(library: openUIChatLibrary(), response: program),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('官方文档'), findsOneWidget);
    expect(find.text('OpenUI'), findsOneWidget);
    expect(find.text('博客文章'), findsOneWidget);
    expect(find.text('[1] '), findsOneWidget);
    expect(find.text('[2] '), findsOneWidget);
  });

  testWidgets('tapping a citation dispatches openUrl', (tester) async {
    final actions = <ActionEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(library: openUIChatLibrary(), response: program, onAction: actions.add),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('[1]'));
    await tester.pump();
    expect(actions.map((a) => a.type), contains('openUrl'));
    expect(actions.firstWhere((a) => a.type == 'openUrl').args, ['https://example.com/docs']);
  });

  testWidgets('out-of-range markers render as plain text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(library: openUIChatLibrary(), response: program),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    expect(rich.text.toPlainText(), contains('[9]'));
    expect(find.text('[9]'), findsNothing);
  });

  testWidgets('innermost Card sources win for nested cards', (tester) async {
    final actions = <ActionEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIChatLibrary(),
            response: '''
root = Card([inner], [{"title": "外层", "url": "https://example.com/outer"}])
inner = Card([t], [{"title": "内层", "url": "https://example.com/inner"}])
t = TextContent("见[1]。")
''',
            onAction: actions.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('[1]'));
    await tester.pump();
    expect(actions.firstWhere((a) => a.type == 'openUrl').args, ['https://example.com/inner']);
  });

  testWidgets('general Card drops sources and renders no strip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIStandardLibrary(),
            response: '''
root = Stack([c])
c = Card([t], [{"title": "官方文档", "url": "https://example.com/docs"}])
t = TextContent("结论见[1]。")
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The sources value lands on the general Card's variant prop and
    // is skipped as a type mismatch: the card still renders, but no
    // strip appears and the marker stays plain text.
    expect(find.text('结论见[1]。'), findsOneWidget);
    expect(find.text('官方文档'), findsNothing);
    expect(find.text('[1]'), findsNothing);
  });
}
