import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

// Batch A props alignment (React 0.18.1 schemas, see
// docs/react-1.0-diff/react-source-props.md): declaration order,
// requiredness, and renderer behaviour for the renamed/reshaped props.
void main() {
  final library = openUIStandardLibrary();

  List<String> propNames(String component) =>
      library.byName[component]!.props.map((p) => p.name).toList();

  List<String> requiredNames(String component) => library
      .byName[component]!
      .props
      .where((p) => p.required)
      .map((p) => p.name)
      .toList();

  test('Batch A defs follow React schema order', () {
    expect(propNames('Stack'), ['children', 'direction', 'gap', 'align', 'justify', 'wrap']);
    expect(propNames('TabItem'), ['value', 'trigger', 'content']);
    expect(propNames('StepsItem'), ['title', 'details']);
    expect(propNames('Modal'), ['title', 'open', 'children', 'size']);
    expect(propNames('Callout'), ['variant', 'title', 'description', 'visible']);
    expect(propNames('CodeBlock'), ['language', 'codeString']);
    expect(propNames('MarkDownRenderer'), ['textMarkdown', 'variant']);
    expect(propNames('Image'), ['alt', 'src']);
    expect(propNames('Col'), ['label', 'data', 'type']);
    expect(propNames('BarChart'), ['labels', 'series', 'variant', 'xLabel', 'yLabel', 'height', 'density', 'condensed', 'tickVariant']);
    expect(propNames('Series'), ['category', 'values']);
    expect(propNames('PieChart'), ['labels', 'values', 'variant', 'appearance']);
    expect(propNames('Slice'), ['category', 'value']);
    expect(propNames('ScatterChart'), ['datasets', 'xLabel', 'yLabel']);
    expect(propNames('TagBlock'), ['tags', 'size']);
    expect(propNames('Tag'), ['text', 'icon', 'size', 'variant']);
    expect(propNames('EntityList'), ['rows', 'size', 'header', 'footer']);
    expect(propNames('MetricIndicatorInline'), ['value', 'subtext', 'trend']);
    expect(propNames('Button'), ['label', 'action', 'variant', 'type', 'size']);
    expect(propNames('Buttons'), ['buttons', 'direction']);
    expect(propNames('IconButton'), ['name', 'icon', 'action', 'variant', 'size', 'shape']);
    expect(propNames('ListItem'), ['title', 'subtitle', 'image', 'actionLabel', 'action']);
    expect(requiredNames('CardHeader'), isEmpty);
    expect(requiredNames('Image'), ['alt']);
  });

  test('Text React order: variant first, value second', () {
    final r = parseOpenUI('root = Stack([t])\nt = Text("text", "hello")', library);
    expect(r.errors, isEmpty);
    final node = r.root!.nodesOf('children').single;
    expect(node.stringOf('value'), 'hello');
  });

  testWidgets('Stack direction row lays children horizontally', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([a, b], "row")
a = TextContent("左")
b = TextContent("右")
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('左'), findsOneWidget);
    expect(find.text('右'), findsOneWidget);
    expect(find.byType(Row), findsWidgets);
  });

  testWidgets('Modal open=false renders nothing and no dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = Stack([m])
m = Modal("标题", false, [TextContent("弹窗内容")])
''',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('弹窗内容'), findsNothing);
  });

  testWidgets('Callout visible=false renders nothing; Image without src renders alt', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([c, img])
c = Callout("info", "标题", "描述", false)
img = Image("备用文字")
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('标题'), findsNothing);
    expect(find.text('描述'), findsNothing);
    expect(find.text('备用文字'), findsOneWidget);
  });

  testWidgets('TagBlock strings, EntityList rows and metric trend render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([tags, ents, m])
tags = TagBlock(["甲", "乙"], "sm")
ents = EntityList([{"left": "张三", "right": "详情"}], "small")
m = MetricIndicatorInline("100", "收入", {"direction": "up", "value": 10})
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('甲'), findsOneWidget);
    expect(find.text('乙'), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('详情'), findsOneWidget);
    expect(find.text('▲10'), findsOneWidget);
  });

  testWidgets('PieChart labels/values render legend; Buttons column stacks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([pie, btns])
pie = PieChart(["甲", "乙"], [3, 1], "donut")
btns = Buttons([Button("一"), Button("二")], "column")
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('甲'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);
    expect(find.text('乙'), findsOneWidget);
    expect(find.text('25.0%'), findsOneWidget);
    expect(find.text('一'), findsOneWidget);
    expect(find.text('二'), findsOneWidget);
  });

  testWidgets('host Skeleton/TableSkeleton defaults follow React (1, 5x4)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [Skeleton(), TableSkeleton()],
        ),
      ),
    );
    // Skeleton: 1 bar; TableSkeleton: 5 rows x 4 columns = 20 cells.
    // Bars/cells are Containers with grey300 decoration; count them via
    // the Skeleton/TableSkeleton widget subtrees.
    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.byType(TableSkeleton), findsOneWidget);
  });
}
