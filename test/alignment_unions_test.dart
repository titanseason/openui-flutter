import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

// React 0.18.1 full alignment (general library): schema unions the
// defs do not carry — FormControl input whitelist, Form fields,
// Tabs/Accordion content, Card/Modal children, Carousel slides,
// list-item types, card-block min(2) — plus the gap defaults
// (Stack/Card "m" = 12, card-block gap = 12, scale xs 6 / l 18 /
// 2xl 36). Chat library enforcement is out of scope: the same
// programs must keep parsing there.

void main() {
  final library = openUIStandardLibrary();

  test('FormControl accepts the 9 union inputs', () {
    for (final input in [
      'Input("x")',
      'TextArea("x")',
      'Select("x", [SelectItem("a", "A")])',
      'DatePicker("x")',
      'Slider("x", "linear", 0, 100)',
      'CheckBoxGroup("x", [CheckBoxItem("A", "desc", "a")])',
      'RadioGroup("x", [RadioItem("A", "desc", "a")])',
      'Chips("x", "multiple", [ChipItem("a", "A")])',
      'OptionCards("x", "single", [OptionCard("a", "A", "desc")])',
    ]) {
      final r = parseOpenUI('root = FormControl("L", $input)', library);
      expect(r.errors, isEmpty, reason: input);
      expect(r.root, isNotNull, reason: input);
    }
  });

  test('FormControl rejects non-union inputs', () {
    for (final input in [
      'SwitchGroup("x", [SwitchItem("A", null, "a")])',
      'EditableTable("x", [], [])',
      'Text("text", "hi")',
    ]) {
      final r = parseOpenUI('root = FormControl("L", $input)', library);
      expect(r.root, isNull, reason: input);
      expect(r.errors.map((e) => e.code), contains('type-mismatch'), reason: input);
    }
  });

  test('Form fields must be FormControl nodes', () {
    final r = parseOpenUI(
      'root = Form("f", Buttons([Button("Go", @ToAssistant("go"))]), [FormControl("City", Input("city")), Text("text", "stray")])',
      library,
    );
    expect(r.errors.map((e) => e.code), contains('type-mismatch'));
    final fields = r.root!.nodesOf('fields');
    expect(fields.length, 1);
    expect(fields.single.component, 'FormControl');
  });

  test('TabItem/AccordionItem content follows ContentChildUnion', () {
    final tabs = parseOpenUI(
      'root = Tabs([TabItem("t", "Tab", [TextContent("ok"), Text("text", "stray")])])',
      library,
    );
    expect(tabs.errors.map((e) => e.code), contains('type-mismatch'));
    final content = tabs.root!.nodesOf('items').single.nodesOf('content');
    expect(content.map((c) => c.component), ['TextContent']);
    final acc = parseOpenUI(
      'root = Accordion([AccordionItem("a", "Panel", [TextContent("ok"), Text("text", "stray")])])',
      library,
    );
    expect(acc.errors.map((e) => e.code), contains('type-mismatch'));
    expect(acc.root!.nodesOf('items').single.nodesOf('content').map((c) => c.component), ['TextContent']);
  });

  test('Card children follow CardChildUnion; Modal children follow ContentChildUnion', () {
    final card = parseOpenUI(
      'root = Card([Stack([TextContent("in stack")]), Text("text", "stray")])',
      library,
    );
    expect(card.errors.map((e) => e.code), contains('type-mismatch'));
    expect(card.root!.nodesOf('children').map((c) => c.component), ['Stack']);
    final modal = parseOpenUI(
      'root = Modal("T", true, [TextContent("ok"), Text("text", "stray")])',
      library,
    );
    expect(modal.errors.map((e) => e.code), contains('type-mismatch'));
    expect(modal.root!.nodesOf('children').map((c) => c.component), ['TextContent']);
  });

  test('Carousel slides follow ContentChildUnion', () {
    final r = parseOpenUI(
      'root = Carousel([[TextContent("ok"), Text("text", "stray")], [TextContent("two")]])',
      library,
    );
    expect(r.errors.map((e) => e.code), contains('type-mismatch'));
    final slides = r.root!.props['children'] as List;
    expect((slides[0] as List).length, 1);
    expect((slides[1] as List).length, 1);
  });

  test('list-item types are enforced', () {
    final r = parseOpenUI(
      'root = Stack([Tabs([TabItem("t", "Tab", [TextContent("x")]), Text("text", "stray")]), Buttons([Button("Go", @ToAssistant("go")), Text("text", "stray")])])',
      library,
    );
    expect(r.errors.map((e) => e.code), contains('type-mismatch'));
    expect(r.root!.nodesOf('children')[0].nodesOf('items').length, 1);
    expect(r.root!.nodesOf('children')[1].nodesOf('buttons').length, 1);
  });

  testWidgets('Stack/Card without gap use 12; named gaps follow the scale', (tester) async {
    Future<void> pump(String body) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            child: OpenUIRenderer(library: library, response: 'root = Stack([$body])\n'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump('Stack([TextContent("a"), TextContent("b")])');
    expect(find.byWidgetPredicate((w) => w is SizedBox && w.height == 12), findsWidgets);
    await pump('Stack([TextContent("a"), TextContent("b")], "column", "l")');
    expect(find.byWidgetPredicate((w) => w is SizedBox && w.height == 18), findsWidgets);
    await pump('Stack([TextContent("a"), TextContent("b")], "column", "xs")');
    expect(find.byWidgetPredicate((w) => w is SizedBox && w.height == 6), findsWidgets);
  });

  testWidgets('card-block grid without gap uses 12', (tester) async {
    // 500 wide viewport: responsive grid is 2 columns, so the gap
    // shows up as the Wrap spacing (at 800 wide the same grid uses
    // rows instead). The width must come from the viewport: a
    // SizedBox cannot shrink below the scroll viewport's width.
    tester.view.physicalSize = const Size(500, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: 'root = SnippetCardBlock([SnippetCardItem(null, Text("text", "一")), SnippetCardItem(null, Text("text", "二"))])\n',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is Wrap && w.spacing == 12 && w.runSpacing == 12), findsOneWidget);
  });
}
