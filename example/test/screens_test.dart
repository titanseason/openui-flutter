import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter_example/screens.dart';

void main() {
  testWidgets('chat rich answer screen pumps without crashing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatRichAnswerScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Q1 Revenue'), findsOneWidget);
  });

  testWidgets('dashboard screen pumps without crashing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pumpAndSettle();
    // Twice: once in the AppBar, once in the CardHeader.
    expect(find.text('Business Dashboard'), findsWidgets);
  });

  testWidgets('form + Query screen pumps without crashing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FormQueryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('City Weather'), findsOneWidget);
  });

  testWidgets('custom component + theme switch screen pumps without crashing',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CustomThemeScreen()));
    await tester.pumpAndSettle();
    // Twice: once in the AppBar, once in the CardHeader.
    expect(find.text('Theme & Custom Components'), findsWidgets);
    // Theme switch + replaced component are both visible and working.
    // The marker proves the Callout is the host builder's output, not
    // the built-in rendering (which has no such header).
    await tester.tap(find.text('Switch to dark'));
    await tester.pumpAndSettle();
    expect(find.text('Host Custom Callout'), findsOneWidget);
    expect(find.text('This is the replaced Callout'), findsOneWidget);
  });
}
