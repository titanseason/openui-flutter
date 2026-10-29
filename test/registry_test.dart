import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_lang/openui_lang.dart';

void main() {
  test('registry lookup and withBuilder do not mutate the original', () {
    const registry = ComponentRegistry();
    expect(registry.lookup('PriceTag'), isNull);
    final next = registry.withBuilder('PriceTag', (context, node, renderChild) => const SizedBox.shrink());
    expect(registry.lookup('PriceTag'), isNull);
    expect(next.lookup('PriceTag'), isNotNull);
  });

  testWidgets('custom component with nested built-in child renders', (tester) async {
    final base = openUIStandardLibrary();
    // Task 3 will add extend(); for Task 1, construct the library directly.
    final library = OpenUILibrary(
      root: base.root,
      components: [
        ...base.components,
        const ComponentDef('PriceTag', 'Test-only custom component.', [
          PropDef('price', PropType.number, required: true),
          PropDef('children', PropType.nodeList, required: true),
        ]),
      ],
    );
    final registry = ComponentRegistry().withBuilder('PriceTag', (context, node, renderChild) {
      return Column(children: [Text('price:${node.numOf('price')}'), renderChild(node.nodesOf('children').first)]);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenUIRenderer(
            library: library,
            registry: registry,
            response: '''
root = Stack([tag])
tag = PriceTag(42, [TextContent("内嵌")])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('price:42.0'), findsOneWidget);
    expect(find.text('内嵌'), findsOneWidget);
  });

  testWidgets('registry builder wins over a built-in component', (tester) async {
    final registry = ComponentRegistry().withBuilder('TextContent', (context, node, renderChild) {
      return Text('custom:${node.stringOf('text')}');
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenUIRenderer(
            library: openUIStandardLibrary(),
            registry: registry,
            response: 'root = TextContent("原")',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('custom:原'), findsOneWidget);
  });
}
