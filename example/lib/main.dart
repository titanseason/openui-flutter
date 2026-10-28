import 'package:flutter/material.dart';
import 'package:openui_flutter/openui_flutter.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenUI Flutter Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text('OpenUI Flutter Demo')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: OpenUIRenderer(
            library: openUIMvpLibrary(),
            response: '''
root = Stack([header, chart, form, tabs])
header = CardHeader("Q1 收入", "全部业务线")
chart = BarChart(months, [rev])
months = ["1月", "2月", "3月"]
rev = Series("收入", [120, 145, 180])
form = Form([name, city, save])
name = Input("姓名", "name")
city = Select([bj, sh], "city")
bj = SelectItem("北京", "bj")
sh = SelectItem("上海", "sh")
save = Button("保存", @Set(\$saved, true))
tabs = Tabs([t1, t2])
t1 = TabItem("概览", [TextContent("这是概览页签")])
t2 = TabItem("明细", [TextContent("这是明细页签")])
''',
            onAction: (e) {},
          ),
        ),
      ),
    );
  }
}
