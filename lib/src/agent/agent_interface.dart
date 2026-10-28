import 'dart:async';

import 'package:flutter/material.dart';

import '../controller.dart';
import '../lang.dart';
import '../library.dart';
import '../renderer.dart';
import 'agent_slots.dart';
import 'agent_storage.dart';
import 'agent_tools.dart';

/// Implemented by the host against its own model provider. The shell
/// never calls a model API directly: it streams [send]'s chunks into
/// an [OpenUIController] for the assistant message being composed.
abstract class AgentLlm {
  Stream<String> send(List<AgentMessage> history, String prompt);
}

/// Chat shell: sidebar thread list, thread header, welcome empty
/// state, composer, workspace/artifact column, and a tool-call
/// timeline. Each assistant message is rendered through its own
/// [OpenUIController] fed by the LLM stream, so streaming behaves
/// exactly like [OpenUIRenderer] streaming elsewhere.
///
/// Customisation: any [AgentSlots] builder, when supplied, replaces
/// its area entirely; when absent, the default renders. Tool calls
/// and artifacts are read-only views supplied by the host: the shell
/// never executes tools itself, it displays what the host's tool
/// layer already ran. Both suppliers are called on every build, so
/// they should be cheap and side-effect free.
class AgentInterface extends StatefulWidget {
  const AgentInterface({
    super.key,
    required this.storage,
    required this.llm,
    this.library,
    this.toolProvider,
    this.onAction,
    this.slots,
    this.toolCalls,
    this.artifacts,
  });
  final AgentStorage storage;
  final AgentLlm llm;
  final OpenUILibrary? library;
  final OpenUIToolProvider? toolProvider;
  final void Function(ActionEvent)? onAction;
  final AgentSlots? slots;
  final List<AgentToolCall> Function()? toolCalls;
  final List<AgentArtifact> Function()? artifacts;

  @override
  State<AgentInterface> createState() => _AgentInterfaceState();
}

class _AgentInterfaceState extends State<AgentInterface> {
  late final OpenUILibrary _library;
  var _threads = <AgentThread>[];
  String? _selectedId;
  var _streaming = false;
  final _composerController = TextEditingController();
  TextEditingController? _titleController;
  final _messageControllers = <int, OpenUIController>{};
  final _actionSubs = <StreamSubscription<ActionEvent>>[];
  String? _selectedArtifactId;

  AgentInterfaceState get _slotState =>
      AgentInterfaceState(currentThread: _selected, isStreaming: _streaming);

  AgentThread? get _selected {
    for (final t in _threads) {
      if (t.id == _selectedId) return t;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _library = widget.library ?? openUIStandardLibrary();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    final threads = await widget.storage.listThreads();
    if (!mounted) return;
    setState(() => _threads = threads);
  }

  @override
  void dispose() {
    _disposeMessageControllers();
    _composerController.dispose();
    _titleController?.dispose();
    super.dispose();
  }

  void _disposeMessageControllers() {
    for (final sub in _actionSubs) {
      unawaited(sub.cancel());
    }
    _actionSubs.clear();
    for (final c in _messageControllers.values) {
      c.dispose();
    }
    _messageControllers.clear();
  }

  OpenUIController _controllerFor(int index, AgentMessage message) {
    final existing = _messageControllers[index];
    if (existing != null) return existing;
    final controller = OpenUIController(library: _library, toolProvider: widget.toolProvider);
    if (message.openUiResponse != null && message.openUiResponse!.isNotEmpty) {
      controller.push(message.openUiResponse!);
      controller.finish();
    }
    if (widget.onAction != null) {
      _actionSubs.add(controller.onAction.listen(widget.onAction));
    }
    _messageControllers[index] = controller;
    return controller;
  }

  Future<void> _selectThread(String id) async {
    _disposeMessageControllers();
    _titleController?.dispose();
    _titleController = null;
    final loaded = await widget.storage.loadThread(id) ??
        _threads.firstWhere((t) => t.id == id, orElse: () => throw StateError('unknown thread $id'));
    if (!mounted) return;
    // Render the loaded thread, not the list entry: a storage that
    // returns fresh copies (any file/DB-backed storage) may hold
    // messages the listed entry does not, and controller indices
    // must line up with the rendered copy.
    final updated = _threads.map((t) => t.id == id ? loaded : t).toList();
    if (!updated.any((t) => t.id == id)) updated.add(loaded);
    setState(() {
      _threads = updated;
      _selectedId = id;
      _titleController = TextEditingController(text: loaded.title);
      for (var i = 0; i < loaded.messages.length; i++) {
        final m = loaded.messages[i];
        if (m.role == 'assistant') _controllerFor(i, m);
      }
    });
  }

  Future<void> _deleteThread(String id) async {
    await widget.storage.deleteThread(id);
    if (!mounted) return;
    if (_selectedId == id) {
      _disposeMessageControllers();
      _titleController?.dispose();
      _titleController = null;
    }
    setState(() {
      _threads = _threads.where((t) => t.id != id).toList();
      if (_selectedId == id) _selectedId = null;
    });
  }

  Future<void> _renameThread(AgentThread thread, String title) async {
    final renamed = AgentThread(id: thread.id, title: title, messages: thread.messages);
    await widget.storage.saveThread(renamed);
    if (!mounted) return;
    setState(() {
      _threads = _threads.map((t) => t.id == thread.id ? renamed : t).toList();
    });
  }

  Future<void> _send() async {
    final prompt = _composerController.text.trim();
    if (prompt.isEmpty || _streaming) return;
    // Set synchronously (before the first await) so a second tap
    // during the save cannot start a second stream; the button
    // itself is disabled by the setState below.
    _streaming = true;
    _composerController.clear();
    var thread = _selected;
    final createdThread = thread == null;
    if (thread == null) {
      thread = AgentThread(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: prompt,
        messages: [],
      );
      _threads = [..._threads, thread];
      _selectedId = thread.id;
      _titleController = TextEditingController(text: thread.title);
    }
    final history = List<AgentMessage>.of(thread.messages);
    final beforeLength = thread.messages.length;
    final userMessage = AgentMessage(role: 'user', text: prompt);
    thread.messages.add(userMessage);
    final assistantIndex = thread.messages.length;
    thread.messages.add(const AgentMessage(role: 'assistant', text: ''));
    final controller = _controllerFor(assistantIndex, thread.messages[assistantIndex]);
    try {
      await widget.storage.saveThread(thread);
    } catch (_) {
      // The first save is outside the streaming try/finally below, so
      // a failure here must not leave the composer disabled forever
      // with the prompt already cleared: roll back the optimistic
      // appends (and a just-created thread), restore the prompt, and
      // re-enable the composer so the user can retry.
      thread.messages.removeRange(beforeLength, thread.messages.length);
      if (createdThread) {
        final failedThread = thread;
        _threads = _threads.where((t) => t.id != failedThread.id).toList();
        _selectedId = null;
        _titleController?.dispose();
        _titleController = null;
      }
      if (!mounted) return;
      _composerController.text = prompt;
      setState(() => _streaming = false);
      return;
    }
    if (!mounted) return;
    setState(() => _streaming = true);
    var accumulated = '';
    try {
      await for (final chunk in widget.llm.send(history, prompt)) {
        if (!mounted) break;
        accumulated += chunk;
        controller.push(chunk);
        thread.messages[assistantIndex] = AgentMessage(
          role: 'assistant',
          text: accumulated,
          openUiResponse: accumulated,
        );
        setState(() {});
      }
    } finally {
      if (mounted) {
        controller.finish();
        setState(() => _streaming = false);
      }
      await widget.storage.saveThread(thread);
    }
  }

  Widget _sidebar() {
    final sidebarSlot = widget.slots?.sidebar;
    if (sidebarSlot != null) return sidebarSlot(context, _slotState);
    return Column(
      children: [
        widget.slots?.sidebarHeader?.call(context, _slotState) ??
            ListTile(
              title: const Text('New chat'),
              leading: const Icon(Icons.add),
              onTap: () {
                _disposeMessageControllers();
                _titleController?.dispose();
                _titleController = null;
                setState(() => _selectedId = null);
              },
            ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            children: [
              for (final thread in _threads)
                ListTile(
                  title: Text(thread.title),
                  selected: thread.id == _selectedId,
                  onTap: () => _selectThread(thread.id),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete thread',
                    onPressed: () => _deleteThread(thread.id),
                  ),
                ),
            ],
          ),
        ),
        if (widget.slots?.sidebarFooter != null)
          widget.slots!.sidebarFooter!(context, _slotState),
      ],
    );
  }

  /// Read-only timeline of the host's tool calls, shown once above
  /// the messages of the selected thread. A call shows its tool name,
  /// a status icon, and its result text when done.
  Widget _toolTimeline() {
    final calls = widget.toolCalls?.call() ?? const <AgentToolCall>[];
    if (calls.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final call in calls)
          ListTile(
            leading: switch (call.status) {
              'done' => const Icon(Icons.check_circle_outline),
              'error' => const Icon(Icons.error_outline),
              _ => const Icon(Icons.autorenew),
            },
            title: Text(call.tool),
            subtitle: call.status == 'done' && call.result != null ? Text(call.result!) : null,
          ),
        const Divider(height: 1),
      ],
    );
  }

  /// Default workspace column: artifact titles; tapping one shows
  /// its content below the list. Only rendered when artifacts are
  /// present; a [AgentSlots.workspace] builder replaces this column.
  Widget _workspaceColumn(List<AgentArtifact> artifacts) {
    final workspaceSlot = widget.slots?.workspace;
    if (workspaceSlot != null) return workspaceSlot(context, _slotState);
    AgentArtifact? selected;
    for (final a in artifacts) {
      if (a.id == _selectedArtifactId) selected = a;
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              for (final artifact in artifacts)
                ListTile(
                  title: Text(artifact.title),
                  selected: artifact.id == _selectedArtifactId,
                  onTap: () => setState(() => _selectedArtifactId = artifact.id),
                ),
            ],
          ),
        ),
        if (selected != null) ...[
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Text(selected.content),
            ),
          ),
        ],
      ],
    );
  }

  Widget _messages(AgentThread thread) {
    return ListView(
      children: [
        for (var i = 0; i < thread.messages.length; i++)
          if (thread.messages[i].role == 'user')
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(12),
                child: Text(thread.messages[i].text),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8),
              child: OpenUIRenderer(
                library: _library,
                controller: _controllerFor(i, thread.messages[i]),
              ),
            ),
      ],
    );
  }

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('agent-composer'),
              controller: _composerController,
              decoration: const InputDecoration(hintText: 'Type a message'),
              onSubmitted: (_) => _send(),
            ),
          ),
          IconButton(
            key: const Key('agent-send'),
            icon: const Icon(Icons.send),
            tooltip: 'Send',
            onPressed: _streaming ? null : _send,
          ),
        ],
      ),
    );
  }

  Widget _main() {
    final thread = _selected;
    final composer = widget.slots?.composer?.call(context, _slotState) ?? _composer();
    if (thread == null) {
      return Column(
        children: [
          Expanded(
            child: widget.slots?.welcome?.call(context, _slotState) ??
                const Center(child: Text('Welcome to OpenUI')),
          ),
          composer,
        ],
      );
    }
    return Column(
      children: [
        widget.slots?.threadHeader?.call(context, _slotState) ??
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('agent-thread-title'),
                      controller: _titleController,
                      decoration: const InputDecoration(border: InputBorder.none),
                      onSubmitted: (value) => _renameThread(thread, value),
                    ),
                  ),
                  IconButton(
                    key: const Key('agent-thread-delete'),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete thread',
                    onPressed: () => _deleteThread(thread.id),
                  ),
                ],
              ),
            ),
        const Divider(height: 1),
        _toolTimeline(),
        Expanded(child: _messages(thread)),
        composer,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final artifacts = widget.artifacts?.call() ?? const <AgentArtifact>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(width: 280, child: _sidebar()),
                const VerticalDivider(width: 1),
                Expanded(child: _main()),
                if (artifacts.isNotEmpty) ...[
                  const VerticalDivider(width: 1),
                  SizedBox(width: 320, child: _workspaceColumn(artifacts)),
                ],
              ],
            ),
          );
        }
        final mobileHeaderSlot = widget.slots?.mobileHeader;
        return Scaffold(
          appBar: mobileHeaderSlot != null
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(kToolbarHeight),
                  child: mobileHeaderSlot(context, _slotState),
                )
              : AppBar(
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ),
          drawer: Drawer(child: _sidebar()),
          body: artifacts.isEmpty
              ? _main()
              : Column(
                  children: [
                    Expanded(child: _main()),
                    SizedBox(height: 240, child: _workspaceColumn(artifacts)),
                  ],
                ),
        );
      },
    );
  }
}
