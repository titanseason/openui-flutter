import 'package:flutter_test/flutter_test.dart';
import 'package:openui_lang/openui_lang.dart';

// Regression tests for the independent review of lib/src/core
// (language layer, f2fbfd4 baseline): JS truthiness/coercion,
// statement cycles, member pluck, node-list drops, query-param
// sentinels, incremental fallback root, context JSON, and the
// lexer fixes. All expectations are upstream (lang-core 1.0.2)
// behavior, not the old Flutter behavior.
void main() {
  final library = openUIStandardLibrary();

  ParseResult run(String program, {Map<String, Object?> queryData = const {}}) {
    return parseOpenUI(program, library, queryData: queryData);
  }

  group('M1 truthiness and short-circuit', () {
    test('ternary follows JS truthiness, not == true', () {
      final r = run(r'''root = Stack([t])
t = TextContent(1 ? "yes" : "no")
''');
      expect(r.root!.nodesOf('children')[0].stringOf('text'), 'yes');
      final r2 = run(r'''root = Stack([t])
t = TextContent(0 ? "yes" : "no")
''');
      expect(r2.root!.nodesOf('children')[0].stringOf('text'), 'no');
      final r3 = run(r'''root = Stack([t])
t = TextContent("" ? "yes" : "no")
''');
      expect(r3.root!.nodesOf('children')[0].stringOf('text'), 'no');
    });

    test('! follows JS truthiness', () {
      final r = run(r'''root = Stack([t])
t = TextContent("v=" + !5)
''');
      expect(r.root!.nodesOf('children')[0].stringOf('text'), 'v=false');
      final r2 = run(r'''root = Stack([t])
t = TextContent("v=" + !0)
''');
      expect(r2.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
      final r3 = run(r'''root = Stack([t])
t = TextContent("v=" + !"")
''');
      expect(r3.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
    });

    test('&& and || return operands and short-circuit', () {
      final r = run(r'''root = Stack([t])
t = TextContent("v=" + (5 && true))
''');
      expect(r.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
      final r2 = run(r'''root = Stack([t])
t = TextContent("v=" + (0 || "dflt"))
''');
      expect(r2.root!.nodesOf('children')[0].stringOf('text'), 'v=dflt');
      // Short-circuit: the right side is never evaluated, so it
      // contributes no unresolved names.
      final r3 = run(r'''root = Stack([t])
t = TextContent("v=" + (false && missing))
''');
      expect(r3.root!.nodesOf('children')[0].stringOf('text'), 'v=false');
      expect(r3.unresolved, isNot(contains('missing')));
      final r4 = run(r'''root = Stack([t])
t = TextContent("v=" + (true || missing))
''');
      expect(r4.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
      expect(r4.unresolved, isNot(contains('missing')));
    });
  });

  group('M2 numeric and comparison coercion', () {
    test('loose equality', () {
      final r = run(r'''root = Stack([t])
t = TextContent("v=" + (5 == "5"))
''');
      expect(r.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
      final r2 = run(r'''root = Stack([t])
t = TextContent("v=" + (5 != "5"))
''');
      expect(r2.root!.nodesOf('children')[0].stringOf('text'), 'v=false');
      final r3 = run(r'''root = Stack([t])
t = TextContent("v=" + (null == null))
''');
      expect(r3.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
      final r4 = run(r'''root = Stack([t])
t = TextContent("v=" + (null == 0))
''');
      expect(r4.root!.nodesOf('children')[0].stringOf('text'), 'v=false');
    });

    test('unparseable strings are NaN in loose equality, not 0', () {
      // JS: Number("abc") is NaN, and NaN equals nothing; the old
      // code mapped NaN to 0 via _toNumber and got all of these
      // backwards. Lists/maps convert to a primitive first, and a
      // null list element joins as an empty string (JS Array join).
      final cases = <String, String>{
        '"abc" == 0': 'v=false',
        '"abc" == false': 'v=false',
        '[1, 2] == 0': 'v=false',
        '{"a": 1} == 0': 'v=false',
        '[null] == ""': 'v=true',
        // Positive controls: parseable paths still compare by value.
        '"5" == 5': 'v=true',
        '[1, 2] == "1,2"': 'v=true',
      };
      for (final entry in cases.entries) {
        final r = run('root = Stack([t])\nt = TextContent("v=" + (${entry.key}))\n');
        expect(
          r.root!.nodesOf('children')[0].stringOf('text'),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('two distinct objects are never loosely equal (identity)', () {
      // JS: == between two objects is identity only; distinct
      // literals are never equal, even with identical contents.
      // An object against a primitive still converts first.
      final cases = <String, String>{
        '[1, 2] == [1, 2]': 'v=false',
        '{"a": 1} == {"a": 1}': 'v=false',
        '[1, 2] == "1,2"': 'v=true',
      };
      for (final entry in cases.entries) {
        final r = run('root = Stack([t])\nt = TextContent("v=" + (${entry.key}))\n');
        expect(
          r.root!.nodesOf('children')[0].stringOf('text'),
          entry.value,
          reason: entry.key,
        );
      }
      // Same reference is equal.
      final r = run(r'''root = Stack([t])
$a = [1, 2]
t = TextContent("v=" + ($a == $a))
''');
      expect(r.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
    });

    test('arithmetic goes through toNumber', () {
      final r = run(r'''root = Stack([t])
t = TextContent("v=" + (null + 1 == 1))
''');
      expect(r.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
      final r2 = run(r'''root = Stack([t])
t = TextContent("v=" + (true + 1 == 2))
''');
      expect(r2.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
      final r3 = run(r'''root = Stack([t])
t = TextContent("v=" + ("5" - 2 == 3))
''');
      expect(r3.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
      final r4 = run(r'''root = Stack([t])
t = TextContent("v=" + ("5" * 2 == 10))
''');
      expect(r4.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
    });

    test('division and modulo by zero return 0', () {
      final r = run(r'''root = Stack([t])
t = TextContent("v=" + (1 / 0))
''');
      expect(r.root!.nodesOf('children')[0].stringOf('text'), 'v=0');
      final r2 = run(r'''root = Stack([t])
t = TextContent("v=" + (1 % 0))
''');
      expect(r2.root!.nodesOf('children')[0].stringOf('text'), 'v=0');
    });

    test('comparisons go through toNumber, not lexicographic order', () {
      final r = run(r'''root = Stack([t])
t = TextContent("v=" + ("10" > "9"))
''');
      expect(r.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
      final r2 = run(r'''root = Stack([t])
t = TextContent("v=" + ("10" < "9"))
''');
      expect(r2.root!.nodesOf('children')[0].stringOf('text'), 'v=false');
      final r3 = run(r'''root = Stack([t])
t = TextContent("v=" + ("abc" > "a"))
''');
      // Non-numeric strings coerce to 0 on both sides: not greater.
      expect(r3.root!.nodesOf('children')[0].stringOf('text'), 'v=false');
    });
  });

  group('M3 statement cycles', () {
    test('plain statement cycle reports a cycle error', () {
      final r = run('a = b\nb = a\nroot = a\n');
      expect(r.root, isNull);
      expect(r.errors.map((e) => e.code), contains('cycle'));
    });

  });

  group('Mixed statement-variable cycles', () {
    test('statement-variable mixed cycle reports a cycle error', () {
      final r = run('a = \$b\n\$b = a\nroot = a\n');
      expect(r.root, isNull);
      expect(r.errors.map((e) => e.code), contains('cycle'));
      // Declaration order does not matter: the same cycle with
      // the variable declared first.
      final r2 = run('\$b = a\na = \$b\nroot = a\n');
      expect(r2.root, isNull);
      expect(r2.errors.map((e) => e.code), contains('cycle'));
    });

    test('longer mixed cycle through two statements', () {
      final r = run('\$b = a\na = c\nc = \$b\nroot = a\n');
      expect(r.root, isNull);
      expect(r.errors.map((e) => e.code), contains('cycle'));
    });

    test('statement cycle reached only through a default', () {
      // The statements form a cycle, but the root only reads the
      // variable, so the live path never evaluates them: before
      // this fix the cycle failed silently (root null, no error).
      final r = run('\$x = a\na = b\nb = a\nroot = \$x\n');
      expect(r.root, isNull);
      expect(r.errors.map((e) => e.code), contains('cycle'));
    });

    test('element-default cycle through a variable reports a cycle error',
        () {
      // $a's live element default reads $b, whose default reads c,
      // which reads $a: the re-entrant read of $a has no frozen
      // value yet, so it closes a cycle instead of returning null.
      final r = run('\$a = TextContent(\$b)\n\$b = c\nc = \$a\nroot = c\n');
      expect(r.errors.map((e) => e.code), contains('cycle'));
    });

    test('forward read through a statement stays null, no error', () {
      // $b's default inlines a, which reads the later $c as null;
      // there is no cycle (nothing reads $b back), so no error.
      // The live value of a is still 5.
      final r = run('\$b = a\na = \$c\n\$c = 5\nroot = TextContent("" + a)');
      expect(r.errors.map((e) => e.code), isNot(contains('cycle')));
      expect(r.root!.stringOf('text'), '5');
    });

    test('direct self-read in a default stays null, no error', () {
      // A default reads only earlier states; itself is not earlier,
      // so a direct self-read is a null read, not a cycle.
      final r = run('root = TextContent("hi")\n\$a = \$a\n');
      expect(r.root, isNotNull);
      expect(r.errors.map((e) => e.code), isNot(contains('cycle')));
    });
  });

  group('M4 member access', () {
    test('array pluck and length', () {
      final r = run(r'''root = Stack([t])
rows = [{"name": "a"}, {"name": "b"}]
t = TextContent("n=" + @Count(rows.name))
''');
      expect(r.root!.nodesOf('children')[0].stringOf('text'), 'n=2');
      final r2 = run(r'''root = Stack([t])
items = [1, 2, 3]
t = TextContent("n=" + items.length)
''');
      expect(r2.root!.nodesOf('children')[0].stringOf('text'), 'n=3');
      final r3 = run(r'''root = Stack([t])
t = TextContent("n=" + "abc".length)
''');
      expect(r3.root!.nodesOf('children')[0].stringOf('text'), 'n=3');
    });
  });

  group('M5 node-list drops', () {
    test('string child in a node list reports type-mismatch', () {
      final r = run('root = Stack(["hello", TextContent("x")])\n');
      expect(r.root, isNotNull);
      expect(r.errors.map((e) => e.code), contains('type-mismatch'));
      expect(r.root!.nodesOf('children').map((c) => c.component), ['TextContent']);
    });

    test('string child nested in a list still reports type-mismatch', () {
      final r = run('root = Stack([["hello"]])\n');
      expect(r.errors.map((e) => e.code), contains('type-mismatch'));
      expect(r.root!.nodesOf('children'), isEmpty);
    });

    test('boolean child in a node list is ignored like React', () {
      // `cond && Node` evaluates to false when cond is false (M1);
      // React ignores boolean children, so false must not report.
      final r = run('root = Stack([false && TextContent("x")])\n');
      expect(r.errors.map((e) => e.code), isNot(contains('type-mismatch')));
      expect(r.root!.nodesOf('children'), isEmpty);
      // Control: true && Node yields the node itself.
      final r2 = run('root = Stack([true && TextContent("x")])\n');
      expect(r2.errors, isEmpty);
      expect(
        r2.root!.nodesOf('children').map((c) => c.component),
        ['TextContent'],
      );
    });
  });

  group('M6 query params never carry sentinels', () {
    // Queries are lazy: root must read q2, otherwise neither query
    // is evaluated and the absence of q2 would prove nothing. With
    // root = q2, q1 is always evaluated (via q2's params) and emits;
    // q2 must not follow it in any of the three cases.
    test('loading param suppresses the request', () {
      final r = run('q1 = Query("t1", {})\nq2 = Query("t2", {"x": q1})\nroot = q2\n',
          queryData: {'q1': queryLoading});
      expect(r.queries.map((q) => q.statementName), contains('q1'));
      expect(r.queries.map((q) => q.statementName), isNot(contains('q2')));
    });

    test('failed param suppresses the request', () {
      final r = run('q1 = Query("t1", {})\nq2 = Query("t2", {"x": q1})\nroot = q2\n',
          queryData: {'q1': const QueryFailed('t1')});
      expect(r.queries.map((q) => q.statementName), contains('q1'));
      expect(r.queries.map((q) => q.statementName), isNot(contains('q2')));
    });

    test('pending query param waits without a request', () {
      final r = run('q1 = Query("t1", {})\nq2 = Query("t2", {"x": q1})\nroot = q2\n');
      expect(r.queries.map((q) => q.statementName), contains('q1'));
      expect(r.queries.map((q) => q.statementName), isNot(contains('q2')));
    });
  });

  group('M7 incremental fallback root', () {
    test('inserted root component above wins on reparse', () {
      final parser = IncrementalOpenUIParser(library);
      final first = parser.parse('b = Stack([TextContent("B")])', streaming: false);
      expect(first.root!.nodesOf('children')[0].stringOf('text'), 'B');
      final second = parser.parse('a = Stack([TextContent("A")])\nb = Stack([TextContent("B")])', streaming: false);
      expect(second.root!.nodesOf('children')[0].stringOf('text'), 'A');
      final full = parseOpenUI('a = Stack([TextContent("A")])\nb = Stack([TextContent("B")])', library);
      expect(second.root!.nodesOf('children')[0].stringOf('text'),
          full.root!.nodesOf('children')[0].stringOf('text'));
    });
  });

  group('M8 context blocks', () {
    test('nested JSON context does not leak closing braces', () {
      final r = run(']]>openui:context\n{\n  "outer": {\n    "inner": 1\n  }\n}\nroot = Stack([TextContent("hi")])\n');
      expect(r.root, isNotNull);
      expect(r.errors.where((e) => e.code == 'parse-failed'), isEmpty);
    });

    test('braces inside JSON strings do not end the context', () {
      final r = run(']]>openui:context\n{\n  "text": "a}b",\n  "nested": {"x": 1}\n}\nroot = Stack([TextContent("hi")])\n');
      expect(r.root, isNotNull);
      expect(r.errors.where((e) => e.code == 'parse-failed'), isEmpty);
    });

    test('incremental context block with nested JSON', () {
      const context = ']]>openui:context\n{\n  "outer": {\n    "inner": 1\n  }\n}\n';
      final parser = IncrementalOpenUIParser(library);
      parser.parse(context, streaming: true);
      final r = parser.parse('${context}root = Stack([TextContent("hi")])\n', streaming: false);
      expect(r.root, isNotNull);
      expect(r.errors.where((e) => e.code == 'parse-failed'), isEmpty);
    });
  });

  group('m1 string escapes', () {
    test('double-quoted unicode escapes decode', () {
      final r = run(r'''root = TextContent("\u0041")''');
      expect(r.root!.stringOf('text'), 'A');
    });

    test('double-quoted backspace and form feed decode', () {
      final r = run(r'''root = TextContent("a\bb")''');
      expect(r.root!.stringOf('text'), 'a\x08b');
      final r2 = run(r'''root = TextContent("a\fb")''');
      expect(r2.root!.stringOf('text'), 'a\x0cb');
    });

    test('malformed double-quoted escape falls back to raw text', () {
      final r = run(r'''root = TextContent("a\xb")''');
      expect(r.root!.stringOf('text'), r'a\xb');
    });

    test('single-quoted unicode escapes keep old behavior', () {
      final r = run(r"""root = TextContent('\u0041')""");
      expect(r.root!.stringOf('text'), 'u0041');
    });
  });

  group('m2 Each keeps nulls', () {
    test('Each maps null results instead of dropping them', () {
      final r = run(r'''root = Stack([t])
t = TextContent("n=" + @Count(@Each([1, null, 3], "t", t)))
''');
      expect(r.root!.nodesOf('children')[0].stringOf('text'), 'n=3');
    });
  });

  group('m3 non-string query tool', () {
    test('numeric tool reports type-mismatch and emits nothing', () {
      // Queries are lazy: root must read q, otherwise it is never
      // evaluated and the error never surfaces.
      final r = run('q = Query(123, {})\nroot = q\n');
      expect(r.queries, isEmpty);
      expect(r.errors.map((e) => e.code), contains('type-mismatch'));
      expect(r.root, isNull);
    });
  });

  group('m4 index conversion', () {
    test('string index converts through toNumber', () {
      final r = run(r'''root = Stack([t])
items = [10, 20, 30]
t = TextContent("v=" + (items["0"] == 10))
''');
      expect(r.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
      final r2 = run(r'''root = Stack([t])
items = [10, 20, 30]
t = TextContent("v=" + (items[1] == 20))
''');
      expect(r2.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
      final r3 = run(r'''root = Stack([t])
o = {"a": 7}
t = TextContent("v=" + (o["a"] == 7))
''');
      expect(r3.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
    });
  });

  group('m5 fallback search', () {
    test('failed fallback candidate does not stop the search', () {
      final r = run('a = Stack()\nb = Stack([TextContent("B")])\n');
      expect(r.root, isNotNull);
      expect(r.root!.nodesOf('children')[0].stringOf('text'), 'B');
    });
  });

  group('m6 scientific notation', () {
    test('exponent literals parse', () {
      final r = run(r'''root = Stack([t])
t = TextContent("v=" + (1e10 == 10000000000))
''');
      expect(r.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
      final r2 = run(r'''root = Stack([t])
t = TextContent("v=" + (1.5e3 == 1500))
''');
      expect(r2.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
      final r3 = run(r'''root = Stack([t])
t = TextContent("v=" + (2E-2 == 0.02))
''');
      expect(r3.root!.nodesOf('children')[0].stringOf('text'), 'v=true');
    });

    test('1else still scans as number plus ident', () {
      final r = run('root = TextContent(1else)\n');
      expect(r.errors.map((e) => e.code), contains('parse-failed'));
    });
  });

  group('Col scalar data (render-layer M5 companion)', () {
    test('scalar data survives parse instead of dropping the column', () {
      // Previously data was typed list, so a scalar failed the
      // parse-time type check and the whole Col was dropped; the
      // renderer wraps scalars via _asArray into a single cell.
      final r = run('root = Table([Col("Name", 42)])\n');
      expect(r.errors.where((e) => e.code == 'type-mismatch'), isEmpty);
      expect(r.root, isNotNull);
      expect(r.root!.component, 'Table');
      final cols = r.root!.nodesOf('columns');
      expect(cols.length, 1);
      expect(cols[0].component, 'Col');
      expect(cols[0].stringOf('label'), 'Name');
      expect(cols[0].props['data'], 42);
    });

    test('list data still works', () {
      final r = run('root = Table([Col("Name", [1, 2])])\n');
      expect(r.errors.where((e) => e.code == 'type-mismatch'), isEmpty);
      final cols = r.root!.nodesOf('columns');
      expect(cols.length, 1);
      expect(cols[0].props['data'], [1, 2]);
    });
  });
}
