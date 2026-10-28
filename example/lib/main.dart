import 'package:flutter/material.dart';
import 'package:openui_flutter_example/screens.dart';

void main() => runApp(const DemoApp());

/// Navigation hub for the four example screens. Each screen is a public
/// widget in screens.dart so it can be pumped on its own in tests.
class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenUI Flutter Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text('OpenUI Flutter Demo')),
        body: ListView(
          children: const [
            _Entry('聊天富回答', ChatRichAnswerScreen()),
            _Entry('业务看板', DashboardScreen()),
            _Entry('表单 + Query', FormQueryScreen()),
            _Entry('主题与自定义组件', CustomThemeScreen()),
          ],
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry(this.label, this.screen);
  final String label;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen),
      ),
    );
  }
}
