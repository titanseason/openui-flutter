import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

void main() {
  testWidgets('MarkdownRenderer uses flutter_markdown_plus for full Markdown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OpenUIRenderer(
              library: openUIMvpLibrary(),
              response: '''
root = MarkdownRenderer("# 标题\\n\\n- 一\\n- 二\\n\\n| a | b |\\n|---|---|\\n| 1 | 2 |\\n\\n> 引用\\n\\n`code` **粗体**")
''',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownBody), findsOneWidget);
  });
}
