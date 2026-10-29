import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_lang/openui_lang.dart';

// The rules validation engine: the pure validateRules function plus
// live FormControl errors (touched fields only).
void main() {
  group('validateRules', () {
    test('required', () {
      expect(validateRules({'required': true}, null), isNotNull);
      expect(validateRules({'required': true}, ''), isNotNull);
      expect(validateRules({'required': true}, []), isNotNull);
      expect(validateRules({'required': true}, {}), isNotNull);
      expect(validateRules({'required': true}, 'x'), isNull);
      expect(validateRules({'required': true}, 0), isNull);
      // Optional fields never fail on empty values.
      expect(validateRules({'email': true}, ''), isNull);
      expect(validateRules({'email': true}, null), isNull);
      expect(validateRules(null, 'x'), isNull);
      expect(validateRules('not-a-map', 'x'), isNull);
    });

    test('email and url', () {
      expect(validateRules({'email': true}, 'a@b.com'), isNull);
      expect(validateRules({'email': true}, 'not-an-email'), isNotNull);
      expect(validateRules({'email': true}, 'a@b'), isNotNull);
      expect(validateRules({'url': true}, 'https://example.com'), isNull);
      expect(validateRules({'url': true}, 'http://example.com/x'), isNull);
      expect(validateRules({'url': true}, 'ftp://example.com'), isNotNull);
      expect(validateRules({'url': true}, 'example.com'), isNotNull);
    });

    test('numeric, min and max', () {
      expect(validateRules({'numeric': true}, 42), isNull);
      expect(validateRules({'numeric': true}, '42'), isNull);
      expect(validateRules({'numeric': true}, 'abc'), isNotNull);
      expect(validateRules({'min': 10}, 10), isNull);
      expect(validateRules({'min': 10}, 9), 'Must be at least 10.');
      expect(validateRules({'max': 20}, 20), isNull);
      expect(validateRules({'max': 20}, 21), 'Must be at most 20.');
      // Lists apply min/max to the first element (e.g. Slider values).
      expect(validateRules({'min': 10}, [15]), isNull);
      expect(validateRules({'min': 10}, [5]), isNotNull);
    });

    test('minLength, maxLength and pattern', () {
      expect(validateRules({'minLength': 3}, 'ab'), isNotNull);
      expect(validateRules({'minLength': 3}, 'abc'), isNull);
      expect(validateRules({'maxLength': 3}, 'abcd'), isNotNull);
      expect(validateRules({'maxLength': 3}, ['a', 'b']), isNull);
      expect(validateRules({'pattern': r'^\d+$'}, '123'), isNull);
      expect(validateRules({'pattern': r'^\d+$'}, '12a'), isNotNull);
      // An invalid pattern cannot fail a value.
      expect(validateRules({'pattern': '['}, 'anything'), isNull);
    });
  });

  group('FormControl live errors', () {
    Future<void> pumpForm(WidgetTester tester, String input, String label) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            child: OpenUIRenderer(
              library: openUIStandardLibrary(),
              response: '''
root = Stack([f])
f = FormControl("$label", $input, "提示")
''',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('required error appears only after the field is touched', (tester) async {
      await pumpForm(tester, 'Input("name", null, null, {"required": true})', '姓名');
      expect(find.text('This field is required.'), findsNothing);
      await tester.enterText(find.byType(TextFormField), 'a');
      await tester.pump();
      expect(find.text('This field is required.'), findsNothing);
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();
      expect(find.text('This field is required.'), findsOneWidget);
    });

    testWidgets('email error shows and clears with the value', (tester) async {
      await pumpForm(tester, 'Input("email", null, null, {"email": true})', '邮箱');
      await tester.enterText(find.byType(TextFormField), 'bad');
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'a@b.com');
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsNothing);
    });

    testWidgets('min/max errors follow the typed value', (tester) async {
      await pumpForm(tester, 'Input("age", null, null, {"min": 10, "max": 20})', '年龄');
      await tester.enterText(find.byType(TextFormField), '5');
      await tester.pump();
      expect(find.text('Must be at least 10.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '25');
      await tester.pump();
      expect(find.text('Must be at most 20.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '15');
      await tester.pump();
      expect(find.text('Must be at least 10.'), findsNothing);
      expect(find.text('Must be at most 20.'), findsNothing);
    });

    testWidgets('untouched declared values show no error', (tester) async {
      await pumpForm(tester, 'Input("email", null, null, {"email": true}, "bad")', '邮箱');
      expect(find.text('Enter a valid email address.'), findsNothing);
    });
  });
}
