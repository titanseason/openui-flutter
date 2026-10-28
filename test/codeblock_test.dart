import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

/// Pumps an [OpenUIRenderer] whose root renders a single CodeBlock node
/// built from [program], using an optional controller (for theme tests).
Future<void> pumpCodeBlock(
  WidgetTester tester,
  String program, {
  OpenUIController? controller,
}) async {
  if (controller != null) {
    controller.push(program);
    controller.finish();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: OpenUIRenderer(library: openUIMvpLibrary(), controller: controller))),
    );
  } else {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: OpenUIRenderer(library: openUIMvpLibrary(), response: program))),
    );
  }
  await tester.pumpAndSettle();
}

/// Collects every RichText in the tree whose plain text contains [needle].
List<RichText> richTextsContaining(WidgetTester tester, String needle) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .where((r) => r.text.toPlainText().contains(needle))
      .toList();
}

/// Counts distinct text styles in a TextSpan tree (root + descendants).
int countStyles(TextSpan span) {
  final styles = <TextStyle?>{span.style};
  void walk(InlineSpan s) {
    if (s is TextSpan) {
      styles.add(s.style);
      for (final c in s.children ?? const <InlineSpan>[]) {
        walk(c);
      }
    }
  }

  for (final c in span.children ?? const <InlineSpan>[]) {
    walk(c);
  }
  return styles.length;
}

const dartProgram = 'root = CodeBlock("void main() { print(1); }", "dart")';

void main() {
  testWidgets('CodeBlock highlights Dart keywords', (tester) async {
    await pumpCodeBlock(tester, dartProgram);
    final found = richTextsContaining(tester, 'void main()');
    expect(found, isNotEmpty);
    // Highlighting applied: the span tree carries more than one style
    // (keyword / punctuation / literal coloured differently).
    expect(countStyles(found.first.text as TextSpan), greaterThan(1));
  });

  testWidgets('CodeBlock falls back to plain text for unknown language', (tester) async {
    await pumpCodeBlock(tester, 'root = CodeBlock("void main() { print(1); }", "klingon")');
    final found = richTextsContaining(tester, 'void main()');
    expect(found, isNotEmpty);
    expect(countStyles(found.first.text as TextSpan), 1);
  });

  testWidgets('CodeBlock falls back to plain text when language is absent', (tester) async {
    await pumpCodeBlock(tester, 'root = CodeBlock("hello world")');
    final found = richTextsContaining(tester, 'hello world');
    expect(found, isNotEmpty);
    expect(countStyles(found.first.text as TextSpan), 1);
  });

  testWidgets('CodeBlock follows the dark theme', (tester) async {
    final controller = OpenUIController(
      library: openUIMvpLibrary(),
      theme: OpenUIThemeData.dark(),
    );
    addTearDown(controller.dispose);
    await pumpCodeBlock(tester, dartProgram, controller: controller);
    final found = richTextsContaining(tester, 'void main()');
    expect(found, isNotEmpty);
    expect(countStyles(found.first.text as TextSpan), greaterThan(1));
    // Dark grammar theme on a dark container, not the light grey one.
    expect(
      find.byWidgetPredicate(
        (w) => w is Container && w.color == const Color(0xFF1E1E1E),
      ),
      findsOneWidget,
    );
  });
}
