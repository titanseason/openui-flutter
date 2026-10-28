import 'package:flutter/widgets.dart';

import 'agent_storage.dart';

/// Snapshot of the shell's state, handed to slot builders. Slots read
/// from this; they never mutate the shell — the shell owns its state.
class AgentInterfaceState {
  const AgentInterfaceState({required this.currentThread, required this.isStreaming});
  final AgentThread? currentThread;
  final bool isStreaming;
}

/// One slot area of the shell. A slot builder, when supplied, replaces
/// that area entirely; when absent (null), the shell's default for
/// that area renders. The workspace slot only applies when artifacts
/// are present (see [AgentInterface]); with no artifacts there is no
/// workspace column for a slot to replace.
class AgentSlots {
  const AgentSlots({
    this.sidebar,
    this.sidebarHeader,
    this.sidebarFooter,
    this.mobileHeader,
    this.threadHeader,
    this.welcome,
    this.composer,
    this.workspace,
  });

  /// Replaces the whole sidebar (list + header + footer). When this
  /// is supplied, [sidebarHeader] and [sidebarFooter] are ignored.
  final Widget Function(BuildContext, AgentInterfaceState)? sidebar;

  /// Rendered at the top of the default sidebar, in place of the
  /// "New chat" entry. Ignored when [sidebar] is supplied.
  final Widget Function(BuildContext, AgentInterfaceState)? sidebarHeader;

  /// Rendered at the bottom of the default sidebar, after the thread
  /// list. Ignored when [sidebar] is supplied.
  final Widget Function(BuildContext, AgentInterfaceState)? sidebarFooter;

  /// Replaces the narrow-layout app bar (menu button). Only used
  /// below the 700px breakpoint; the wide layout has no app bar.
  final Widget Function(BuildContext, AgentInterfaceState)? mobileHeader;

  /// Replaces the thread header row (title field + delete button)
  /// shown above a selected thread's messages.
  final Widget Function(BuildContext, AgentInterfaceState)? threadHeader;

  /// Replaces the welcome empty state shown when no thread is selected.
  final Widget Function(BuildContext, AgentInterfaceState)? welcome;

  /// Replaces the composer (text field + send button) in both the
  /// welcome state and the thread view.
  final Widget Function(BuildContext, AgentInterfaceState)? composer;

  /// Replaces the default workspace column shown on the right when
  /// artifacts are present. The builder receives no artifact list:
  /// a custom workspace must close over the host's artifact source.
  final Widget Function(BuildContext, AgentInterfaceState)? workspace;
}
