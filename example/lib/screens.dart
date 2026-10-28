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
      appBar: AppBar(title: const Text('聊天富回答')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: OpenUIRenderer(
          library: openUIStandardLibrary(),
          response: '''
root = Stack([header, note, table, chart, callout])
header = CardHeader("Q1 收入", "全部业务线")
note = TextContent("一季度收入稳步增长，3 月创单月新高。")
table = Table([m, v])
m = Col("月份", ["1月", "2月", "3月"])
v = Col("收入（万）", [120, 145, 180])
chart = BarChart(["1月", "2月", "3月"], [rev])
rev = Series("收入", [120, 145, 180])
callout = Callout("提示：3 月含一笔大客户回款。", "info")
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
/// the HorizontalBarChart's category titles under rotation, and the
/// 2-category RadarChart (fl_chart needs >= 3 entries, so it renders
/// as a padded triangle rather than the old degenerate line).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('业务看板')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: OpenUIRenderer(
          library: openUIStandardLibrary(),
          response: '''
root = Stack([title, hbar, radar, pie, heat, mini])
title = CardHeader("业务看板", "各维度一览")
hbar = HorizontalBarChart(["华北", "华东", "华南"], [s1])
s1 = Series("销售额", [320, 280, 240])
radar = RadarChart(["质量", "速度"], [rs])
rs = Series("本季", [80, 65])
pie = PieChart([p1, p2])
p1 = Slice("线上", 60)
p2 = Slice("线下", 40)
heat = HeatmapChart(["周一", "周二"], [h1])
h1 = Series("访问量", [10, 30])
mini = MiniBarChart([5, 12, 8, 20])
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
    if (city == '上海') return {'rows': ['晴', '多云']};
    return {'rows': ['晴', '多云', '雨']};
  }

  @override
  void initState() {
    super.initState();
    _controller = OpenUIController(
      library: openUIStandardLibrary(),
      toolProvider: _provider,
      initialState: const {'city': '北京'},
    );
    _controller.push('''
root = Stack([title, form, count, retry])
title = CardHeader("城市天气", "输入城市，查询返回行数")
form = Form([city])
city = Input("城市", "city")
count = TextContent("" + @Count(weather.rows))
weather = Query("get_weather", {"city": \$city}, {"rows": []})
retry = Button("刷新", Action([@Run(weather)]))
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
      appBar: AppBar(title: const Text('表单 + Query')),
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
title = CardHeader("主题与自定义组件", "切换主题，Callout 已被替换")
callout = Callout("这是被替换的 Callout", "info")
note = TextContent("下面的 Callout 不是内置渲染，而是宿主通过 registry 替换的。")
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
            const Text('宿主自定义 Callout',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(node.props['text'] as String? ?? ''),
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
      appBar: AppBar(title: const Text('主题与自定义组件')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _toggleTheme,
              child: Text(_dark ? '切换浅色' : '切换深色'),
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
