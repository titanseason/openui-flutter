import 'package:flutter/material.dart';
import 'package:openui_flutter/openui_flutter.dart';

/// Four example screens, one per scenario in the Task 9 brief. Each screen
/// is a public widget (not just code inside main()) so the example's own
/// test suite can pump it, and so hosts can copy a single screen.
///
/// Only public API is used here: no `src/` imports. The Lang programs in
/// this file are mirrored in the package's `test/conformance_test.dart`
/// (the package suite cannot import the example package — that would be a
/// circular path dependency — so the conformance scaffold pins the same
/// programs through the renderer directly).

/// Screen 1: a chat rich answer — header, prose, table, chart, callout.
class ChatRichAnswerScreen extends StatelessWidget {
  const ChatRichAnswerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Rich Answer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: OpenUIRenderer(
          library: openUIStandardLibrary(),
          response: '''
root = Stack([header, note, table, chart, callout])
header = CardHeader("Q1 Revenue", "All business lines")
note = TextContent("Q1 revenue grew steadily, with March hitting a monthly high.")
table = Table([m, v])
m = Col("Month", ["Jan", "Feb", "Mar"])
v = Col("Revenue (10k)", [120, 145, 180])
chart = BarChart(["Jan", "Feb", "Mar"], [rev])
rev = Series("Revenue", [120, 145, 180])
callout = Callout("info", "Note", "Note: March includes a large client payment.")
''',
        ),
      ),
    );
  }
}

/// Screen 2: a simple dashboard.
///
/// Visual checks for Task 6 that cannot be eyeballed in a headless
/// sandbox live here, for a human to confirm on a real device:
/// the HorizontalBarChart's category titles (now drawn horizontal
/// on the left, not rotated), and the 2-category RadarChart (now
/// drawn as its true geometry, a line, not a padded triangle).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: OpenUIRenderer(
          library: openUIStandardLibrary(),
          response: '''
root = Stack([title, hbar, radar, pie, bar, trend])
title = CardHeader("Business Dashboard", "All dimensions at a glance")
hbar = HorizontalBarChart(["North", "East", "South"], [s1])
s1 = Series("Sales", [320, 280, 240])
radar = RadarChart(["Quality", "Speed"], [rs])
rs = Series("This quarter", [80, 65])
pie = PieChart(["Online", "Offline"], [60, 40])
bar = BarChart(["Mon", "Tue"], [h1])
h1 = Series("Visits", [10, 30])
trend = LineChart(["W1", "W2", "W3", "W4"], [t1])
t1 = Series("Trend", [5, 12, 8, 20])
''',
        ),
      ),
    );
  }
}

/// Screen 3: a form driving a Query. Typing a city re-runs the Query
/// because its params depend on `$city`; the count below the form is
/// the number of rows the fake provider returned.
class FormQueryScreen extends StatefulWidget {
  const FormQueryScreen({super.key});

  @override
  State<FormQueryScreen> createState() => _FormQueryScreenState();
}

class _FormQueryScreenState extends State<FormQueryScreen> {
  late final OpenUIController _controller;

  static Future<Object?> _provider(
      String tool, Map<String, Object?> params) async {
    if (tool != 'get_weather') throw StateError('unknown tool $tool');
    final city = params['city'];
    if (city == 'Shanghai') return {'rows': ['Sunny', 'Cloudy']};
    return {'rows': ['Sunny', 'Cloudy', 'Rain']};
  }

  @override
  void initState() {
    super.initState();
    _controller = OpenUIController(
      library: openUIStandardLibrary(),
      toolProvider: _provider,
      initialState: const {'city': 'Beijing'},
    );
    _controller.push('''
root = Stack([title, form, count, retry])
title = CardHeader("City Weather", "Type a city, see the row count")
form = Form("weather", Buttons([Button("Submit", @ToAssistant("submit"))]), [fc])
fc = FormControl("City", Input("city"))
count = TextContent("" + @Count(weather.rows))
weather = Query("get_weather", {"city": \$city}, {"rows": []})
retry = Button("Refresh", Action([@Run(weather)]))
''');
    _controller.finish();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Form + Query')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: OpenUIRenderer(
          library: openUIStandardLibrary(),
          controller: _controller,
        ),
      ),
    );
  }
}

/// Screen 4: the acceptance demo for host customisation — a theme switch
/// AND a replaced component on the same screen. The theme switch rebuilds
/// the controller with `OpenUIThemeData.light()` / `.dark()`; the Callout
/// below is not the built-in rendering but a host builder registered
/// through `ComponentRegistry.withBuilder`.
class CustomThemeScreen extends StatefulWidget {
  const CustomThemeScreen({super.key});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  var _dark = false;
  late OpenUIController _controller;

  static const _program = '''
root = Stack([title, callout, note])
title = CardHeader("Theme & Custom Components", "Switch theme, Callout is replaced")
callout = Callout("info", "Replaced Callout", "This is the replaced Callout")
note = TextContent("The Callout below is not the built-in rendering, but a host replacement via the registry.")
''';

  @override
  void initState() {
    super.initState();
    _rebuildController();
  }

  void _rebuildController() {
    final registry = ComponentRegistry().withBuilder(
      'Callout',
      (context, node, renderChild) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.purple, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Host Custom Callout',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(node.props['description'] as String? ?? ''),
          ],
        ),
      ),
    );
    _controller = OpenUIController(
      library: openUIStandardLibrary(),
      theme: _dark ? OpenUIThemeData.dark() : OpenUIThemeData.light(),
      registry: registry,
    );
    _controller.push(_program);
    _controller.finish();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    setState(() {
      _dark = !_dark;
      _controller.dispose();
      _rebuildController();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Theme & Custom Components')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _toggleTheme,
              child: Text(_dark ? 'Switch to light' : 'Switch to dark'),
            ),
            OpenUIRenderer(
              library: openUIStandardLibrary(),
              controller: _controller,
            ),
          ],
        ),
      ),
    );
  }
}
