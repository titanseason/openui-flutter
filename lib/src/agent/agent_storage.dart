/// Storage for [AgentThread]s. The shell never assumes a backend: the
/// host implements this against whatever it persists to (in-memory,
/// a file, a database). All methods are async so a host backed by
/// real I/O needs no adapter.
abstract class AgentStorage {
  Future<List<AgentThread>> listThreads();
  Future<AgentThread?> loadThread(String id);
  Future<void> saveThread(AgentThread thread);
  Future<void> deleteThread(String id);
}

/// One conversation. [messages] is a mutable list: the shell appends
/// the user message and then the streaming assistant message to it
/// and persists the thread via [AgentStorage.saveThread].
class AgentThread {
  const AgentThread({required this.id, required this.title, required this.messages});
  final String id;
  final String title;
  final List<AgentMessage> messages;
}

/// One message. [role] is `'user'` or `'assistant'`. For assistant
/// messages, [text] is the accumulated raw LLM output and
/// [openUiResponse] is the same text (kept as a separate field so
/// the shell can render it as an OpenUI program without re-deriving
/// it from [text]).
class AgentMessage {
  const AgentMessage({required this.role, required this.text, this.openUiResponse});
  final String role;
  final String text;
  final String? openUiResponse;
}
