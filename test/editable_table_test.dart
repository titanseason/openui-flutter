import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_lang/openui_lang.dart';

// EditableTable in its React shape: name/columns objects/data rows,
// edited rows submitted on "Save Changes" keyed by name.
void main() {
  final library = openUIStandardLibrary();

  test('EditableTable def follows the React schema', () {
    final def = library.byName['EditableTable']!;
    expect(def.props.map((p) => p.name).toList(), ['name', 'columns', 'data']);
    expect(def.props[0].defaultValue, '');
    expect(def.props[1].defaultValue, []);
    expect(def.props[2].defaultValue, []);
  });

  testWidgets('renders headers, values and Save Changes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([t])
t = EditableTable("staff", [{"type": "text", "key": "name", "header": "姓名"}, {"type": "number", "key": "age", "header": "年龄"}], [{"id": "r1", "values": ["a", 30]}])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('姓名'), findsOneWidget);
    expect(find.text('年龄'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });

  testWidgets('select column edits and number cell parses to num on Save', (tester) async {
    final states = <Map<String, Object?>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = Stack([t])
t = EditableTable("staff", [{"type": "select", "key": "role", "header": "角色", "options": [{"value": "admin", "label": "管理员"}, {"value": "user", "label": "用户"}]}, {"type": "number", "key": "age", "header": "年龄"}], [{"id": "r1", "values": ["user", 30]}])
''',
          onStateUpdate: states.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Object?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理员'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '42');
    await tester.pump();
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(states.last['staff'], equals([
      {'id': 'r1', 'values': ['admin', 42]},
    ]));
  });

  testWidgets('date-single cell opens a picker and Save writes the picked date', (tester) async {
    final states = <Map<String, Object?>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = Stack([t])
t = EditableTable("staff", [{"type": "date-single", "key": "day", "header": "日期"}], [{"id": "r1", "values": ["2026-01-15"]}])
''',
          onStateUpdate: states.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(states.last['staff'], equals([
      {'id': 'r1', 'values': ['2026-01-15']},
    ]));
  });

  testWidgets('empty EditableTable renders Save Changes without crashing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OpenUIRenderer(
          library: library,
          response: '''
root = Stack([t])
t = EditableTable()
''',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Save Changes'), findsOneWidget);
  });
}
