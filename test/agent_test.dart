import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

class FakeStorage implements AgentStorage {
  FakeStorage(this.threads);
  final Map<String, AgentThread> threads;
  var saveCalls = 0;
  var deleteCalls = <String>[];

  @override
  Future<List<AgentThread>> listThreads() async => threads.values.toList();

  @override
  Future<AgentThread?> loadThread(String id) async => threads[id];

  @override
  Future<void> saveThread(AgentThread thread) async {
    threads[thread.id] = thread;
    saveCalls++;
  }

  @override
  Future<void> deleteThread(String id) async {
    threads.remove(id);
    deleteCalls.add(id);
  }
}

class FakeLlm implements AgentLlm {
  @override
  Stream<String> send(List<AgentMessage> history, String prompt) async* {
    yield 'root = Stack([';
    yield 'TextContent("hi")])';
  }
}

AgentThread thread(String id, String title, List<AgentMessage> messages) =>
    AgentThread(id: id, title: title, messages: messages);

Future<void> pumpShell(WidgetTester tester, AgentStorage storage) async {
  await pumpShellWithLlm(tester, storage, FakeLlm());
}

Future<void> pumpShellWithLlm(WidgetTester tester, AgentStorage storage, AgentLlm llm) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AgentInterface(storage: storage, llm: llm),
    ),
  );
  await tester.pumpAndSettle();
}

/// LLM whose stream waits for [gate] before yielding, so the test can
/// observe the in-flight (send disabled) state deterministically.
class GatedLlm implements AgentLlm {
  GatedLlm(this.gate);
  final Completer<void> gate;

  @override
  Stream<String> send(List<AgentMessage> history, String prompt) async* {
    await gate.future;
    yield 'root = Stack([TextContent("hi")])';
  }
}

/// Storage whose [loadThread] returns a fresh copy that differs from
/// the listed entry — the shape any file/DB-backed storage has. The
/// shell must render the loaded copy, not the stale list entry.
class FreshCopyStorage implements AgentStorage {
  @override
  Future<List<AgentThread>> listThreads() async => [
        thread('t1', 'Thread One', [
          const AgentMessage(role: 'user', text: 'listed only'),
        ]),
      ];

  @override
  Future<AgentThread?> loadThread(String id) async => thread(id, 'Thread One', [
        const AgentMessage(role: 'user', text: 'loaded fresh'),
        const AgentMessage(
          role: 'assistant',
          text: 'root = Stack([TextContent("fresh")])',
          openUiResponse: 'root = Stack([TextContent("fresh")])',
        ),
      ]);

  @override
  Future<void> saveThread(AgentThread thread) async {}

  @override
  Future<void> deleteThread(String id) async {}
}

/// Storage whose first [saveThread] throws and later saves succeed,
/// so a failed send can be retried.
class ThrowOnceStorage extends FakeStorage {
  ThrowOnceStorage(super.threads);
  var throwNextSave = true;

  @override
  Future<void> saveThread(AgentThread thread) async {
    if (throwNextSave) {
      throwNextSave = false;
      throw Exception('save failed');
    }
    return super.saveThread(thread);
  }
}

void main() {
  // Note: the narrow-screen drawer fallback (sidebar behind a menu
  // button) is implemented minimally in this task; only the wide
  // layout is exercised here (the default 800px test surface).
  testWidgets('AgentInterface lists threads, switches, and sends a message', (tester) async {
    final storage = FakeStorage({
      't1': thread('t1', 'Thread One', [
        const AgentMessage(role: 'user', text: 'hello one'),
      ]),
      't2': thread('t2', 'Thread Two', [
        const AgentMessage(role: 'user', text: 'hello two'),
      ]),
    });
    await pumpShell(tester, storage);

    // Welcome empty state: no thread selected yet.
    expect(find.text('Thread One'), findsOneWidget);
    expect(find.text('Thread Two'), findsOneWidget);
    expect(find.text('hello one'), findsNothing);

    // Tap second thread, its messages shown.
    await tester.tap(find.text('Thread Two'));
    await tester.pumpAndSettle();
    expect(find.text('hello two'), findsOneWidget);

    // Type in composer, tap send: user text and streamed assistant UI.
    await tester.enterText(find.byKey(const Key('agent-composer')), 'hello again');
    await tester.tap(find.byKey(const Key('agent-send')));
    await tester.pumpAndSettle();
    expect(find.text('hello again'), findsOneWidget);
    expect(find.text('hi'), findsOneWidget);
    expect(storage.saveCalls, greaterThan(0));
    expect(storage.threads['t2']!.messages.last.role, 'assistant');
  });

  testWidgets('thread header renames and deletes', (tester) async {
    final storage = FakeStorage({
      't1': thread('t1', 'Old Title', [
        const AgentMessage(role: 'user', text: 'hello'),
      ]),
    });
    await pumpShell(tester, storage);
    await tester.tap(find.text('Old Title'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('agent-thread-title')), 'New Title');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(storage.threads['t1']!.title, 'New Title');

    await tester.tap(find.byKey(const Key('agent-thread-delete')));
    await tester.pumpAndSettle();
    expect(storage.threads.containsKey('t1'), isFalse);
    expect(storage.deleteCalls, contains('t1'));
  });

  testWidgets('switching threads renders the freshly loaded thread', (tester) async {
    await pumpShell(tester, FreshCopyStorage());
    await tester.tap(find.text('Thread One'));
    await tester.pumpAndSettle();
    expect(find.text('loaded fresh'), findsOneWidget);
    expect(find.text('fresh'), findsOneWidget);
    expect(find.text('listed only'), findsNothing);
  });

  testWidgets('a throwing save before streaming restores the composer', (tester) async {
    final storage = ThrowOnceStorage({
      't1': thread('t1', 'Thread One', []),
    });
    await pumpShell(tester, storage);
    await tester.tap(find.text('Thread One'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('agent-composer')), 'hello fail');
    await tester.tap(find.byKey(const Key('agent-send')));
    await tester.pumpAndSettle();
    // Prompt restored, composer usable again, no phantom message sent.
    expect(find.text('hello fail'), findsOneWidget);
    final send = tester.widget<IconButton>(find.byKey(const Key('agent-send')));
    expect(send.onPressed, isNotNull);
    expect(storage.threads['t1']!.messages, isEmpty);

    // Retry now succeeds: the first failure did not poison the shell.
    await tester.tap(find.byKey(const Key('agent-send')));
    await tester.pumpAndSettle();
    expect(find.text('hi'), findsOneWidget);
  });

  testWidgets('a throwing save from welcome state rolls back the new thread', (tester) async {
    final storage = ThrowOnceStorage({'t1': thread('t1', 'Thread One', [])});
    await pumpShell(tester, storage);
    // No thread selected: welcome state.
    expect(find.text('Welcome to OpenUI'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('agent-composer')), 'hello new');
    await tester.tap(find.byKey(const Key('agent-send')));
    await tester.pumpAndSettle();
    // Back to welcome (no half-created thread selected), prompt restored.
    expect(find.text('Welcome to OpenUI'), findsOneWidget);
    expect(find.text('hello new'), findsOneWidget);
    final send = tester.widget<IconButton>(find.byKey(const Key('agent-send')));
    expect(send.onPressed, isNotNull);
  });

  testWidgets('composer send is disabled while streaming', (tester) async {
    final storage = FakeStorage({
      't1': thread('t1', 'Thread One', []),
    });
    final gate = Completer<void>();
    await pumpShellWithLlm(tester, storage, GatedLlm(gate));
    await tester.tap(find.text('Thread One'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('agent-composer')), 'hi');
    await tester.tap(find.byKey(const Key('agent-send')));
    // Stream in flight (gated): send button must be disabled.
    await tester.pump();
    await tester.pump();
    final send = tester.widget<IconButton>(find.byKey(const Key('agent-send')));
    expect(send.onPressed, isNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('hi'), findsWidgets);
  });
}
