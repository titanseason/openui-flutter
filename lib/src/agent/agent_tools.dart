/// One tool call, as reported by the host's LLM/tool layer. These are
/// read-only views: the shell never executes a tool itself, it only
/// displays what the host already ran (via the `toolCalls` supplier
/// on [AgentInterface]).
class AgentToolCall {
  const AgentToolCall({
    required this.tool,
    required this.params,
    this.result,
    this.status = 'running',
  });
  final String tool;
  final Map<String, dynamic> params;
  final String? result;

  /// `'running'`, `'done'` or `'error'`.
  final String status;
}

/// One workspace artifact. Tapping its title in the workspace column
/// shows [content]; the shell does not interpret the content.
class AgentArtifact {
  const AgentArtifact({
    required this.id,
    required this.title,
    required this.content,
  });
  final String id;
  final String title;
  final String content;
}
