import 'package:flutter_test/flutter_test.dart';
import 'package:openui_lang/openui_lang.dart';

void main() {
  final library = openUIStandardLibrary();

  test('autocloser closes string, list and call', () {
    expect(autoCloseOpenUI('TextContent("Hel'), 'TextContent("Hel")');
    expect(autoCloseOpenUI('Stack([a, b'), 'Stack([a, b])');
    expect(autoCloseOpenUI('TextContent("a]b"'), 'TextContent("a]b")');
    expect(autoCloseOpenUI('Stack([a,'), 'Stack([a])');
  });

  test('streaming push renders a half-written line, complete lines stay stable', () {
    final sp = StreamingParser(library);
    final r = sp.push('root = TextContent("Hel');
    expect(r.root, isNotNull);
    expect(r.root!.stringOf('text'), 'Hel');
    final r2 = sp.push('lo")\n');
    expect(r2.root!.stringOf('text'), 'Hello');
  });

  test('a half-written Query does not register as a request until its line ends', () {
    final sp = StreamingParser(library);
    final r = sp.push('root = Stack([t])\nt = TextContent("" + @Count(items.rows))\nitems = Query("list_tools", {},');
    expect(r.queries, isEmpty);
    final r2 = sp.push(' {rows: []})\n');
    expect(r2.queries.length, 1);
    expect(r2.queries.first.tool, 'list_tools');
    expect(r2.queries.first.hasInitial, isTrue);
  });

  test('Query without initial renders as skeleton, with initial renders initial', () {
    final noInitial = parseOpenUI('''
root = TextContent("" + @Count(tickets.rows))
tickets = Query("list_tickets", {"status": "open"})
''', library);
    expect(noInitial.queries.length, 1);
    expect(noInitial.queries.first.tool, 'list_tickets');
    expect(noInitial.queries.first.params['status'], 'open');
    expect(noInitial.root!.component, '__Skeleton');

    final withInitial = parseOpenUI('''
root = TextContent("" + @Count(tickets.rows))
tickets = Query("list_tickets", {}, {"rows": [1, 2]})
''', library);
    expect(withInitial.root!.stringOf('text'), '2');
  });

  test('queryData overrides initial and drives field and index access', () {
    final r = parseOpenUI('''
root = TextContent(first.status)
first = tickets.rows[0]
tickets = Query("list_tickets", {}, {"rows": []})
''', library, queryData: {
      'tickets': {
        'rows': [
          {'status': 'open'},
          {'status': 'closed'},
        ],
      },
    });
    expect(r.root!.stringOf('text'), 'open');
  });

  test('index access on literals and out-of-range', () {
    final r = parseOpenUI('''
root = TextContent(rows[1].name)
rows = [{"name": "A"}, {"name": "B"}]
''', library);
    expect(r.root!.stringOf('text'), 'B');
    final out = parseOpenUI('''
root = TextContent("" + rows[5])
rows = [1]
''', library);
    expect(out.root!.stringOf('text'), '');
  });

  test('Mutation is collected, not rendered as a value', () {
    final r = parseOpenUI('''
root = Stack([btn])
btn = Button("重试", Action([@Run(retry)]))
retry = Mutation("retry_deployment", {"project": "prod"})
''', library);
    expect(r.mutations.length, 1);
    expect(r.mutations.first.tool, 'retry_deployment');
    expect(r.mutations.first.params['project'], 'prod');
    expect(r.root, isNotNull);
  });

  test('Query params can come from a \$variable', () {
    final r = parseOpenUI(r'''
$city = "Tokyo"
root = TextContent("" + @Count(weather.rows))
weather = Query("get_weather", {"city": $city}, {"rows": []})
''', library);
    expect(r.queries.first.params['city'], 'Tokyo');
  });
}
