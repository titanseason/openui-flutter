import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

// React official-name aliases (see docs/react-1.0-diff/): the 11 names
// @openuidev/react-ui 0.18.1 registers that the short-name canonicals
// did not cover. An alias accepts the canonical's props and renders
// through the same renderer case; props-level alignment with the
// official Zod schemas is separate work.
const _aliases = {
  'MarkDownRenderer': 'MarkdownRenderer',
  'SnippetCardBlock': 'SnippetBlock',
  'SnippetCardItem': 'SnippetItem',
  'OverviewCardBlock': 'OverviewBlock',
  'OverviewCardItem': 'OverviewItem',
  'ContextCardBlock': 'ContextBlock',
  'ContextCardItem': 'ContextItem',
  'CompositeCardBlock': 'CompositeBlock',
  'CompositeCardItem': 'CompositeItem',
  'VisualCardBlock': 'VisualBlock',
  'VisualCardItem': 'VisualItem',
};

void main() {
  final library = openUIStandardLibrary();

  test('all 11 React official names are registered with canonical props', () {
    for (final entry in _aliases.entries) {
      final alias = library.byName[entry.key];
      final canonical = library.byName[entry.value];
      expect(alias, isNotNull, reason: 'missing alias ${entry.key}');
      expect(canonical, isNotNull, reason: 'missing canonical ${entry.value}');
      expect(
        alias!.props.map((p) => '${p.name}:${p.required}').toList(),
        canonical!.props.map((p) => '${p.name}:${p.required}').toList(),
        reason: 'alias ${entry.key} props differ from ${entry.value}',
      );
    }
  });

  test('library prompt lists the alias names', () {
    final prompt = library.prompt();
    for (final name in _aliases.keys) {
      expect(prompt, contains('$name('), reason: 'prompt missing $name');
    }
  });

  testWidgets('alias programs render through the canonical cases', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OpenUIRenderer(
              library: library,
              response: '''
root = Stack([md, block])
md = MarkDownRenderer("# Hi")
block = SnippetCardBlock("Tips", [SnippetCardItem("first")])
''',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Hi'), findsOneWidget);
    expect(find.text('Tips'), findsOneWidget);
    expect(find.text('first'), findsOneWidget);
  });
}
