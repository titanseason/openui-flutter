import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_lang/openui_lang.dart';

// Batch C props alignment (React 0.18.1 schemas, see
// docs/react-1.0-diff/react-source-props.md §2, "Forms"): declaration
// order, requiredness, name-keyed state, and renderer behaviour for
// the whole Form family. Old `bind`/`children`/`label`-on-input
// programs do NOT keep working: Lang calls are positional, so an old
// program binds its old list argument to the new string `name` prop
// and fails with type-mismatch (see the last test).
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

  test('Batch C defs follow React schema order and requiredness', () {
    expect(propNames('Form'), ['name', 'buttons', 'fields']);
    expect(propNames('FormControl'), ['label', 'input', 'hint']);
    expect(propNames('Label'), ['text']);
    expect(propNames('Input'), ['name', 'placeholder', 'type', 'rules', 'value']);
    expect(propNames('TextArea'), ['name', 'placeholder', 'rows', 'rules', 'value']);
    expect(propNames('Select'), ['name', 'items', 'placeholder', 'rules', 'value', 'size']);
    expect(propNames('SelectItem'), ['value', 'label']);
    expect(propNames('DatePicker'), ['name', 'mode', 'rules', 'value']);
    expect(propNames('Slider'), ['name', 'variant', 'min', 'max', 'step', 'defaultValue', 'label', 'rules', 'value']);
    expect(propNames('CheckBoxGroup'), ['name', 'items', 'rules', 'value']);
    expect(propNames('CheckBoxItem'), ['label', 'description', 'name', 'defaultChecked']);
    expect(propNames('RadioGroup'), ['name', 'items', 'defaultValue', 'rules', 'value']);
    expect(propNames('RadioItem'), ['label', 'description', 'value']);
    expect(propNames('SwitchGroup'), ['name', 'items', 'variant', 'value']);
    expect(propNames('SwitchItem'), ['label', 'description', 'name', 'defaultChecked']);
    expect(propNames('Chips'), ['name', 'type', 'items', 'rules', 'defaultValue']);
    expect(propNames('ChipItem'), ['value', 'label', 'icon', 'disabled']);
    expect(propNames('OptionCards'), ['name', 'type', 'items', 'rules', 'defaultValue']);
    expect(propNames('OptionCard'), ['value', 'title', 'subtitle', 'topContent', 'disabled']);

    expect(requiredNames('Form'), ['name', 'buttons']);
    expect(requiredNames('FormControl'), ['label', 'input']);
    expect(requiredNames('Input'), ['name']);
    expect(requiredNames('TextArea'), ['name']);
    expect(requiredNames('Select'), ['name', 'items']);
    expect(requiredNames('SelectItem'), ['value', 'label']);
    expect(requiredNames('DatePicker'), ['name']);
    expect(requiredNames('Slider'), ['name', 'variant', 'min', 'max']);
    expect(requiredNames('CheckBoxGroup'), ['name', 'items']);
    expect(requiredNames('CheckBoxItem'), ['label', 'description', 'name']);
    expect(requiredNames('RadioGroup'), ['name', 'items']);
    expect(requiredNames('RadioItem'), ['label', 'description', 'value']);
    expect(requiredNames('SwitchGroup'), ['name', 'items']);
    expect(requiredNames('SwitchItem'), ['name']);
    expect(requiredNames('Chips'), ['name']);
    expect(requiredNames('ChipItem'), ['value', 'label']);
    expect(requiredNames('OptionCards'), ['name']);
    expect(requiredNames('OptionCard'), ['value', 'title']);

    expect(library.byName['Chips']!.props[1].defaultValue, 'multiple');
    expect(library.byName['Chips']!.props[2].defaultValue, const []);
    expect(library.byName['OptionCards']!.props[1].defaultValue, 'single');
    expect(library.byName['OptionCards']!.props[2].defaultValue, const []);
    expect(library.byName['Form']!.props[2].defaultValue, const []);
  });

  test('Form node holds name, buttons node and fields list', () {
    final r = parseOpenUI('''
root = Form("contact", Buttons([Button("Send", @ToAssistant("send"))]), [fc])
fc = FormControl("Name", Input("name"))
''', library);
    expect(r.errors, isEmpty, reason: r.errors.toString());
    final form = r.root!;
    expect(form.component, 'Form');
    expect(form.stringOf('name'), 'contact');
    expect(form.nodeOf('buttons')!.component, 'Buttons');
    expect(form.nodesOf('fields').single.component, 'FormControl');
  });

  testWidgets('Form renders fields then buttons; FormControl renders label, input, hint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Form("contact", Buttons([Button("Send", @ToAssistant("send"))]), [fc, fc2])
fc = FormControl("Name", Input("name"), "Your full name")
fc2 = FormControl("City", Input("city"))
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Your full name'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
  });

  testWidgets('rules.required renders a marker on the FormControl label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([fc, fc2])
fc = FormControl("Name", Input("name", null, null, {"required": true}))
fc2 = FormControl("Nick", Input("nick"))
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Name *'), findsOneWidget);
    expect(find.text('Nick'), findsOneWidget);
  });

  testWidgets('typing into Input and TextArea writes state under name', (tester) async {
    var state = <String, Object?>{};
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([inp, area])
inp = Input("city", "Type a city", "text")
area = TextArea("note", null, 3)
''',
            onStateUpdate: (s) => state = s,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'shanghai');
    await tester.enterText(fields.at(1), 'hello');
    await tester.pump();
    expect(state['city'], 'shanghai');
    expect(state['note'], 'hello');
  });

  testWidgets('password Input obscures text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: 'root = Input("pwd", null, "password")',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // TextFormField exposes no obscureText getter; the underlying
    // EditableText does.
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.obscureText, isTrue);
  });

  testWidgets('Select shows placeholder and writes the item value under name', (tester) async {
    var state = <String, Object?>{};
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Select("city", [SelectItem("beijing", "Beijing"), SelectItem("shanghai", "Shanghai")], "Pick a city")
''',
            onStateUpdate: (s) => state = s,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pick a city'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<Object>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shanghai').last);
    await tester.pumpAndSettle();
    expect(state['city'], 'shanghai');
  });

  testWidgets('DatePicker renders placeholder and picks a date into state', (tester) async {
    var state = <String, Object?>{};
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: 'root = DatePicker("date")',
            onStateUpdate: (s) => state = s,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('未选择'), findsOneWidget);
    await tester.tap(find.text('选择日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final iso = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    expect(state['date'], iso);
  });

  testWidgets('Slider shows array value and writes back a one-element array', (tester) async {
    var state = <String, Object?>{};
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: 'root = Slider("vol", "continuous", 0, 100, null, null, "Volume", null, [50])',
            onStateUpdate: (s) => state = s,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Volume: 50'), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.pump();
    final written = state['vol'];
    expect(written, isA<List>());
    expect((written as List).length, 1);
    expect((written.first as num).toDouble(), 100.0);
  });

  testWidgets('CheckBoxGroup writes a name-to-boolean record; SwitchGroup renders standalone', (tester) async {
    var state = <String, Object?>{};
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([cb, sw])
cb = CheckBoxGroup("prefs", [CheckBoxItem("Email", "By email", "email", true), CheckBoxItem("SMS", "By sms", "sms")])
sw = SwitchGroup("toggles", [SwitchItem("Alerts", "Push alerts", "alerts", true)])
''',
            onStateUpdate: (s) => state = s,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    await tester.tap(find.text('SMS'));
    await tester.pump();
    expect(state['prefs'], {'email': true, 'sms': true});
    await tester.tap(find.text('Alerts'));
    await tester.pump();
    expect(state['toggles'], {'alerts': false});
  });

  testWidgets('RadioGroup writes the selected value; OptionCards single and multiple write values', (tester) async {
    var state = <String, Object?>{};
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([rg, cards, multi])
rg = RadioGroup("size", [RadioItem("Small", "desc", "s"), RadioItem("Large", "desc", "l")], "s")
cards = OptionCards("plan", "single", [OptionCard("free", "Free", "No cost"), OptionCard("pro", "Pro", "Paid")])
multi = OptionCards("adds", "multiple", [OptionCard("a1", "Add one"), OptionCard("a2", "Add two")])
''',
            onStateUpdate: (s) => state = s,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Large'));
    await tester.pump();
    expect(state['size'], 'l');
    await tester.tap(find.text('Pro'));
    await tester.pump();
    expect(state['plan'], 'pro');
    await tester.tap(find.text('Add one'));
    await tester.pump();
    expect(state['adds'], ['a1']);
    await tester.tap(find.text('Add two'));
    await tester.pump();
    expect(state['adds'], ['a1', 'a2']);
  });

  testWidgets('Chips single writes a string, multiple writes a list; disabled chip does nothing', (tester) async {
    var state = <String, Object?>{};
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = Stack([one, many])
one = Chips("city", "single", [ChipItem("beijing", "Beijing"), ChipItem("shanghai", "Shanghai")])
many = Chips("tags", "multiple", [ChipItem("a", "A"), ChipItem("b", "B", null, true)])
''',
            onStateUpdate: (s) => state = s,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shanghai'));
    await tester.pump();
    expect(state['city'], 'shanghai');
    await tester.tap(find.text('A'));
    await tester.pump();
    expect(state['tags'], ['a']);
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(state['tags'], ['a']);
  });

  testWidgets('OptionCard renders title, subtitle and topContent node', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: OpenUIRenderer(
            library: library,
            response: '''
root = OptionCards("plan", "single", [OptionCard("pro", "Pro", "Paid tier", IconText("star", null, null, "Star"))])
''',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Paid tier'), findsOneWidget);
    expect(find.text('Star'), findsOneWidget);
  });

  test('FormControl rejects SwitchGroup: the input union is enforced', () {
    // React's FormControl input union is Input, TextArea, Select,
    // DatePicker, Slider, CheckBoxGroup, RadioGroup, Chips,
    // OptionCards — SwitchGroup is not a member, so the node drops.
    final r = parseOpenUI('root = FormControl("Toggles", SwitchGroup("toggles", [SwitchItem("Alerts", null, "alerts")]))', library);
    expect(r.root, isNull);
    expect(r.errors.map((e) => e.code), contains('type-mismatch'));
    final ok = parseOpenUI('root = FormControl("City", Input("city"))', library);
    expect(ok.errors, isEmpty);
    expect(ok.root, isNotNull);
  });

  test('old form programs fail with the mapper behaviour they actually hit', () {
    // Positional mapping binds the old list argument to the new
    // string `name` prop: type-mismatch, and the node is dropped.
    final oldForm = parseOpenUI('root = Form([Input("name")])', library);
    expect(oldForm.errors.map((e) => e.code), contains('type-mismatch'));
    final oldControl = parseOpenUI('root = FormControl("姓名", [Input("name")], "提示")', library);
    expect(oldControl.errors.map((e) => e.code), contains('type-mismatch'));
    final oldSelect = parseOpenUI('root = Select([SelectItem("a", "a")])', library);
    expect(oldSelect.errors.map((e) => e.code), contains('type-mismatch'));
    // Missing a required prop, and too many positional args.
    final missing = parseOpenUI('root = Input()', library);
    expect(missing.errors.map((e) => e.code), contains('missing-required'));
    final excess = parseOpenUI('root = Input("a", null, null, null, null, "extra")', library);
    expect(excess.errors.map((e) => e.code), contains('excess-args'));
    // Slider without its required variant/min/max.
    final slider = parseOpenUI('root = Slider("vol")', library);
    expect(slider.errors.map((e) => e.code), contains('missing-required'));
  });
}
