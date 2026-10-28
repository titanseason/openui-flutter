import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

// Names aligned directly with @openuidev/react-ui 0.18.1 (see
// docs/react-1.0-diff/): no short-name variants are kept. The 11
// renamed components are MarkDownRenderer and the five
// *CardBlock/*CardItem pairs. Name alignment is names only: props
// are still this library's props, not the official Zod schemas.
const _reactNames = [
  'MarkDownRenderer',
  'SnippetCardBlock',
  'SnippetCardItem',
  'OverviewCardBlock',
  'OverviewCardItem',
  'ContextCardBlock',
  'ContextCardItem',
  'CompositeCardBlock',
  'CompositeCardItem',
  'VisualCardBlock',
  'VisualCardItem',
];

const _removedShortNames = [
  'MarkdownRenderer',
  'SnippetBlock',
  'SnippetItem',
  'OverviewBlock',
  'OverviewItem',
  'ContextBlock',
  'ContextItem',
  'CompositeBlock',
  'CompositeItem',
  'VisualBlock',
  'VisualItem',
];

void main() {
  final library = openUIStandardLibrary();

  test('all 11 React 0.18.1 names are registered', () {
    for (final name in _reactNames) {
      expect(library.byName[name], isNotNull, reason: 'missing $name');
    }
    expect(library.components.length, 95);
  });

  test('short names are gone, not kept as aliases', () {
    for (final name in _removedShortNames) {
      expect(library.byName[name], isNull, reason: '$name should be removed');
    }
    expect(library.prompt(), isNot(contains('SnippetBlock(')));
  });

  testWidgets('React-named programs render', (tester) async {
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
