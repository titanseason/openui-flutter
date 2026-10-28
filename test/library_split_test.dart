import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

// The general/chat library split: membership, roots, and the
// chat-only SectionBlock/SectionItem shapes.
void main() {
  test('general library excludes chat-only components', () {
    final lib = openUIStandardLibrary();
    expect(lib.root, 'Stack');
    expect(lib.components.length, 91);
    for (final name in ['FollowUpBlock', 'FollowUpItem', 'SectionBlock', 'SectionItem']) {
      expect(lib.byName[name], isNull);
    }
    expect(lib.byName['Card']!.props.map((p) => p.name), contains('variant'));
    expect(lib.byName['Card']!.props.map((p) => p.name), isNot(contains('sources')));
  });

  test('chat library excludes general-only components', () {
    final lib = openUIChatLibrary();
    expect(lib.root, 'Card');
    expect(lib.components.length, 93);
    expect(lib.byName['Stack'], isNull);
    expect(lib.byName['Modal'], isNull);
    for (final name in ['FollowUpBlock', 'FollowUpItem', 'SectionBlock', 'SectionItem']) {
      expect(lib.byName[name], isNotNull);
    }
    expect(lib.byName['Card']!.props.map((p) => p.name), contains('sources'));
    expect(lib.byName['Card']!.props.map((p) => p.name), isNot(contains('variant')));
  });

  test('general library rejects a chat-only program', () {
    final r = parseOpenUI('root = Card([SectionBlock([SectionItem("s", "标题", [TextContent("内")])])])', openUIStandardLibrary());
    expect(r.errors.map((e) => e.code), contains('unknown-component'));
  });

  test('chat library rejects a general-only program', () {
    final r = parseOpenUI('root = Stack([TextContent("内")])', openUIChatLibrary());
    expect(r.errors.map((e) => e.code), contains('unknown-component'));
  });

  test('extend keeps the chat library membership', () {
    final lib = openUIChatLibrary().extend(builders: {'A': (context, node, renderChild) => const SizedBox.shrink()});
    expect(lib.byName['SectionBlock'], isNotNull);
    expect(lib.byName['Stack'], isNull);
  });

  testWidgets('SectionBlock renders trigger and content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIChatLibrary(),
            response: '''
root = Card([sec])
sec = SectionBlock([SectionItem("s", "分组项", [TextContent("分组内容")])])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('分组项'), findsOneWidget);
    expect(find.text('分组内容'), findsOneWidget);
  });

  testWidgets('foldable SectionBlock hides content until tapped', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: openUIChatLibrary(),
            response: '''
root = Card([sec])
sec = SectionBlock([SectionItem("s", "分组项", [TextContent("分组内容")])], true)
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('分组项'), findsOneWidget);
    expect(find.text('分组内容'), findsNothing);
    await tester.tap(find.text('分组项'));
    await tester.pumpAndSettle();
    expect(find.text('分组内容'), findsOneWidget);
  });
}
