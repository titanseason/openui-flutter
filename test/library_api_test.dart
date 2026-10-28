import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

void main() {
  test('extend replaces a component and prompt lists custom actions', () {
    final lib = openUIMvpLibrary().extend(
      components: [const ComponentDef('Text', 'Replaced.', [PropDef('text', PropType.string, required: true)])],
      actions: [const ActionDef('Share', 'Share it', [PropDef('id', PropType.string, required: true)])],
    );
    expect(lib.byName['Text']!.description, 'Replaced.');
    expect(lib.prompt(), contains('Share('));
  });

  test('extend remove, add-wins-over-remove, later-wins, and no mutation', () {
    final base = openUIMvpLibrary();
    final extended = base.extend(
      remove: ['Text', 'Card'],
      components: [
        const ComponentDef('Card', 'New card.', [PropDef('children', PropType.nodeList, required: true)]),
        const ComponentDef('Text', 'First.', [PropDef('text', PropType.string, required: true)]),
        const ComponentDef('Text', 'Second.', [PropDef('text', PropType.string, required: true)]),
      ],
      functions: [defineFunction(name: 'Double', description: 'Double it', params: [const PropDef('n', PropType.number, required: true)], fn: (args) => (args['n'] as num) * 2)],
    );
    // Card was removed and re-added, so it survives; Text is the later def.
    expect(extended.byName['Card']!.description, 'New card.');
    expect(extended.byName['Text']!.description, 'Second.');
    expect(extended.functionsByName, contains('Double'));
    // The receiver is unchanged.
    expect(base.byName['Text']!.description, isNot('Second.'));
    expect(base.functionsByName, isNot(contains('Double')));
    expect(extended.prompt(), contains('@Double('));
  });

  test('extend keeps the root and merges builders across chained extends', () {
    final lib = openUIMvpLibrary(root: 'Card')
        .extend(builders: {'A': (context, node, renderChild) => const SizedBox.shrink()})
        .extend(builders: {'B': (context, node, renderChild) => const SizedBox.shrink()});
    expect(lib.root, 'Card');
    expect(lib.registry!.lookup('A'), isNotNull);
    expect(lib.registry!.lookup('B'), isNotNull);
  });

  test('openUIStandardLibrary matches openUIMvpLibrary', () {
    final a = openUIStandardLibrary();
    final b = openUIMvpLibrary();
    expect(a.root, b.root);
    expect(a.components.map((c) => c.name).toList(), b.components.map((c) => c.name).toList());
    expect(a.prompt(), b.prompt());
  });

  test('prompt options: preamble, rules, examples, includeBuiltins', () {
    final lib = openUIMvpLibrary().extend(
      actions: [const ActionDef('Share', 'Share it', [PropDef('id', PropType.string, required: true)])],
    );
    final full = lib.prompt(
      preamble: 'You are a UI generator.',
      additionalRules: ['Never invent component names.'],
      examples: ['root = Stack([TextContent("hi")])'],
    );
    expect(full.startsWith('You are a UI generator.'), isTrue);
    expect(full, contains('Never invent component names.'));
    expect(full, contains('root = Stack([TextContent("hi")])'));
    expect(full, contains('@Count('));
    expect(full, contains('Share('));
    final noBuiltins = lib.prompt(includeBuiltins: false);
    expect(noBuiltins, isNot(contains('@Count(')));
    expect(noBuiltins, isNot(contains('Built-in functions')));
    // Custom actions are not built-ins, so they stay.
    expect(noBuiltins, contains('Share('));
  });

  test('custom action with wrong argument type is a no-op', () {
    final lib = openUIMvpLibrary().extend(
      actions: [const ActionDef('Share', 'Share it', [PropDef('id', PropType.string, required: true)])],
    );
    final result = parseOpenUI('root = Button("Go", @Share(42))', lib);
    expect(result.root!.props['action'], isNull);
    expect(result.errors.map((e) => e.code), contains('runtime-error'));
  });

  test('custom action missing a required argument is a no-op', () {
    final lib = openUIMvpLibrary().extend(
      actions: [const ActionDef('Share', 'Share it', [PropDef('id', PropType.string, required: true)])],
    );
    final result = parseOpenUI('root = Button("Go", @Share())', lib);
    expect(result.root!.props['action'], isNull);
    expect(result.errors.map((e) => e.code), contains('runtime-error'));
  });

  test('valid custom action passes through, undeclared action still passes through', () {
    final lib = openUIMvpLibrary().extend(
      actions: [const ActionDef('Share', 'Share it', [PropDef('id', PropType.string, required: true)])],
    );
    final ok = parseOpenUI('root = Button("Go", @Share("abc"))', lib);
    final action = ok.root!.props['action'] as ActionValue;
    expect(action.name, 'Share');
    expect(action.args, ['abc']);
    expect(ok.errors, isEmpty);
    final undeclared = parseOpenUI('root = Button("Go", @Zap(1, 2))', lib);
    final zap = undeclared.root!.props['action'] as ActionValue;
    expect(zap.name, 'Zap');
    expect(zap.args, [1, 2]);
  });

  test('action name colliding with a built-in is rejected', () {
    expect(
      () => openUIMvpLibrary().extend(
        actions: [const ActionDef('Set', 'Clash.', [PropDef('x', PropType.string, required: true)])],
      ),
      throwsArgumentError,
    );
    expect(
      () => OpenUILibrary(root: 'Stack', components: const [], actions: const [
        ActionDef('ToAssistant', 'Clash.', []),
        ActionDef('ToAssistant', 'Dup.', []),
      ]),
      throwsArgumentError,
    );
  });

  testWidgets('extend builders render through library.registry without a separate registry argument', (tester) async {
    final lib = openUIMvpLibrary().extend(
      components: [const ComponentDef('PriceTag', 'Test-only custom component.', [PropDef('label', PropType.string, required: true)])],
      builders: {
        'PriceTag': (context, node, renderChild) => Text('tag:${node.stringOf('label')}'),
      },
    );
    expect(lib.registry, isNotNull);
    expect(lib.registry!.lookup('PriceTag'), isNotNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenUIRenderer(
            library: lib,
            response: 'root = Stack([PriceTag("x")])',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('tag:x'), findsOneWidget);
  });

  testWidgets('explicit registry argument wins over library.registry', (tester) async {
    final lib = openUIMvpLibrary().extend(
      components: [const ComponentDef('PriceTag', 'Test-only custom component.', [PropDef('label', PropType.string, required: true)])],
      builders: {
        'PriceTag': (context, node, renderChild) => const Text('from-library'),
      },
    );
    final explicit = ComponentRegistry().withBuilder('PriceTag', (context, node, renderChild) => const Text('from-explicit'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenUIRenderer(
            library: lib,
            registry: explicit,
            response: 'root = Stack([PriceTag("x")])',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('from-explicit'), findsOneWidget);
    expect(find.text('from-library'), findsNothing);
  });
}
