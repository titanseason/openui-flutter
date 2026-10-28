# OpenUI Flutter Full React Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Flutter port to full parity with the OpenUI React implementation: an externally friendly, modular SDK (registry, controller, theme) plus every React-side capability not yet in Flutter (hand primitives, extra charts, AgentInterface chat shell), without breaking the existing 86 components, Lang parsing, or Query/Mutation wiring.

**Architecture:** Keep the proven split (pure-Dart Lang core, Flutter renderer) and add one layer on top: a component-builder registry and an `OpenUIController` that own state, Query data, actions and errors, so the renderer becomes a thin mapping from `ElementNode` to widgets. New capabilities land as new modules behind that registry, never by editing the old giant switch for a special case.

**Tech Stack:** Flutter 3.47.6 / Dart 3.13.5 (host toolchain at `~/flutter`), `flutter_markdown_plus` 1.0.12 for Markdown only, self-drawn charts (no chart package), `flutter_test` for all tests.

**Spec:** `README.md` in this repo (current state: 86 components, Query/Mutation, streaming autocloser, 33 tests), the 2026-10-14 research doc `~/workspace/your_files/openui-react-ui-components.html` (@openuidev/react-ui 0.17.0, three layers: GenUI library, hand primitives, AgentInterface), and the previous brainstorm scheme delivered 2026-10-28 (one package, layered internally, no multi-package split).

## Global Constraints

- Flutter SDK only plus `flutter_markdown_plus`; no new third-party dependency without an explicit user decision in that task.
- `openUIMvpLibrary()` keeps working as a deprecated alias; its component names and positional-argument order are a breaking-change red line.
- Lang semantics already shipped (line statements, positional args, forward references, last-definition-wins, root entry + fallback, `@ToAssistant/@OpenUrl/@Set/@Reset/@Run`, custom functions, built-ins, Query/Mutation) must not change meaning.
- Every task ends with `flutter analyze` clean and `flutter test` all green; a task that cannot meet both is not done.
- No network, no Gateway, no server reimplementation: the host supplies data through `toolProvider`; Gateway/Autofix stay external services, not code in this repo.
- Local git only: commit per task on `main` in `~/workspace/openui-flutter`, no remote, no push unless the user explicitly says push.
- Modal, EditableTable and Query-error behaviour changed by this plan are documented in README in the same task that changes them.

## Review Focus

- A host registers a custom component that itself contains built-in components: the custom builder must receive a working `renderChild` that renders nested nodes with the same theme, state and Query data, not a bare widget with no context.
- A Query fails, then the user taps `@Run` on that Query: the failed state must clear and the tool must be called again, and the UI must move from error back to data, not stay stuck on the old skeleton.
- A streaming response arrives one token at a time with a half-written Query line: no tool call may fire with partial parameters, and the half-written component must still render via autocloser.
- A form value changes (`$variable` via `@Set` or a bound input) so a Query's parameters change: the renderer must refetch with the new parameters and must not show stale data as if it were fresh.
- An AgentInterface thread is restored from stored messages: the stored `]]>openui:` content, context and form state must reproduce the same UI and form values, not just the last prose paragraph.
- Each line above gets its test in the owning task below (Tasks 1, 4, 7 respectively, plus Task 4 for the streaming and parameter-change lines).

---

## File Structure

New files are created per responsibility; existing files are split only where a task says so, never as a drive-by refactor.

- `lib/src/registry.dart` — component-builder registry (Task 1).
- `lib/src/controller.dart` — `OpenUIController`, action/error streams, Query store (Task 2).
- `lib/src/theme.dart` — `OpenUIThemeData`, colour scheme, chart palette, skeleton/error builders (Task 2).
- `lib/src/library.dart` — gains `extend()` and prompt options (Task 3, modify).
- `lib/src/lang.dart` — gains message-protocol helpers and action-definition types (Task 4, modify; no split in this plan).
- `lib/src/renderer.dart` — gains registry lookup, controller mode, dialog Modal, bound EditableTable, Query-error view (Tasks 1, 2, 4, modify).
- `lib/src/primitives.dart` — Skeleton, TableSkeleton, Citation, Sources (Task 5).
- `lib/src/extra_charts.dart` — Heatmap, Funnel, CalendarHeatmap, Mini charts, StackedLegend, condensed variants (Task 6).
- `lib/src/agent/` — `agent_interface.dart`, `agent_slots.dart`, `agent_storage.dart`, `agent_tools.dart` (Tasks 7–8).
- `lib/openui_flutter.dart` — barrel export, updated per task (modify).
- `example/lib/main.dart` — extended per task into a full demo (Task 9, modify).
- `test/registry_test.dart`, `test/controller_theme_test.dart`, `test/library_api_test.dart`, `test/lang_parity_test.dart`, `test/primitives_test.dart`, `test/extra_charts_test.dart`, `test/agent_test.dart`, `test/conformance_test.dart` — one per task (create).

---

### Task 1: Component registry and custom components

**Files:**
- Create: `lib/src/registry.dart`
- Modify: `lib/src/renderer.dart`, `lib/openui_flutter.dart`
- Test: `test/registry_test.dart`

**Interfaces:**
- Consumes: `ElementNode` from `lib/src/lang.dart` (fields `component`, `props`, `statementId`; methods `stringOf`, `numOf`, `nodesOf`).
- Produces: `typedef OpenUIComponentBuilder = Widget Function(BuildContext context, ElementNode node, Widget Function(ElementNode) renderChild);`, `class ComponentRegistry { const ComponentRegistry({Map<String, OpenUIComponentBuilder> builders = const {}}); OpenUIComponentBuilder? lookup(String name); ComponentRegistry withBuilder(String name, OpenUIComponentBuilder builder); }`, and `OpenUIRenderer({..., ComponentRegistry? registry})`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('custom component with nested built-in child renders', (tester) async {
  final registry = ComponentRegistry().withBuilder('PriceTag', (context, node, renderChild) {
    return Column(children: [Text('price:${node.numOf('price')}'), renderChild(node.nodesOf('children').first)]);
  });
  // Pump OpenUIRenderer with a library extended by PriceTag (see Task 3 for
  // the final extend API; for this task, register via a test-only library
  // that includes the PriceTag ComponentDef) and a root using it.
  // Expect: finds 'price:42' and the nested TextContent text.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/flutter/bin/flutter test test/registry_test.dart`
Expected: FAIL with "ComponentRegistry isn't defined" (or the custom node renders empty).

- [ ] **Step 3: Implement `ComponentRegistry` in `lib/src/registry.dart`, wire `OpenUIRenderer.registry` into `_buildNode`**

Lookup order: registry builder first, built-in switch second, unknown component last (skeleton, never a crash). `renderChild` passed to a builder must call the renderer's own `_buildNode` for that child, so theme, state and Query data flow through unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run: `~/flutter/bin/flutter test test/registry_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/registry.dart lib/src/renderer.dart lib/openui_flutter.dart test/registry_test.dart
git commit -m "feat: component registry for custom components"
```

### Task 2: OpenUIController and theme

**Files:**
- Create: `lib/src/controller.dart`, `lib/src/theme.dart`
- Modify: `lib/src/renderer.dart`, `lib/openui_flutter.dart`
- Test: `test/controller_theme_test.dart`

**Interfaces:**
- Consumes: `ComponentRegistry` (Task 1), `OpenUILibrary`, `OpenUIToolProvider` (existing renderer typedef).
- Produces: `class OpenUIThemeData { const OpenUIThemeData({required this.colors, required this.chartPalette, this.cardRadius = 12, this.skeletonBuilder, this.errorBuilder}); static OpenUIThemeData light(); static OpenUIThemeData dark(); }`, `class OpenUIColorScheme { const OpenUIColorScheme({required this.primary, required this.surface, required this.onSurface}); }`, `class OpenUIController { OpenUIController({required this.library, this.toolProvider, this.theme, this.registry}); OpenUIThemeData get effectiveTheme; Stream<ActionEvent> get onAction; Stream<OpenUIError> get onError; Map<String, Object?> get formState; void push(String chunk); ParseResult finish(); Future<void> runAction(Object? action); void dispose(); }` (`theme` is nullable; `effectiveTheme` returns `theme ?? OpenUIThemeData.light()`, because a static factory call cannot be a const default value), and `OpenUIRenderer({..., OpenUIController? controller})` (controller mode wins over the old `response`/`onAction` parameters when both are given; old parameters keep working alone).

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('controller theme changes chart palette without changing data', (tester) async {
  // Two controllers, same response, different chartPalette; pump both.
  // Expect: both show the same series label, and the controller's
  // formState updates after tapping a bound Chips item.
});
test('controller emits a Query error on its error stream', () async {
  // toolProvider throws; expect: first event on controller.onError is
  // an OpenUIError whose message contains the tool name.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/flutter/bin/flutter test test/controller_theme_test.dart`
Expected: FAIL with "OpenUIController isn't defined".

- [ ] **Step 3: Implement `OpenUIThemeData` and `OpenUIController`**

Controller owns: form state, Query data/params/failed state (reuse the existing renderer rules: failed Query is not retried until an explicit `@Run`), action dispatch (including Mutation failure stopping an action list), and streaming buffer via the existing `StreamingParser`. Renderer in controller mode reads theme from the controller and uses the controller's skeleton/error builders when supplied; otherwise it keeps the current defaults.

- [ ] **Step 4: Run test to verify it passes**

Run: `~/flutter/bin/flutter test test/controller_theme_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/controller.dart lib/src/theme.dart lib/src/renderer.dart lib/openui_flutter.dart test/controller_theme_test.dart
git commit -m "feat: OpenUIController and theme"
```

### Task 3: Library API parity (extend, prompt options, custom actions)

**Files:**
- Modify: `lib/src/lang.dart` (action-definition types only), `lib/src/library.dart`
- Test: `test/library_api_test.dart`

**Interfaces:**
- Consumes: `ComponentDef`, `PropDef`, `FunctionDef` (existing).
- Produces: `OpenUILibrary extend({List<ComponentDef> components = const [], List<ComponentDef> remove = const [], List<FunctionDef> functions = const [], Map<String, OpenUIComponentBuilder> builders = const {}})` (add wins over remove for the same name; a later component with an existing name replaces it; builders are stored as the library's `ComponentRegistry registry`, and the renderer checks an explicit `registry` argument first, then `library.registry`), plus a top-level `openUIStandardLibrary()` function with the same result as `openUIMvpLibrary()`, which is kept as a deprecated alias, `String prompt({String? preamble, List<String> additionalRules = const [], List<String> examples = const [], bool includeBuiltins = true})`, `class ActionDef { const ActionDef(this.name, this.description, this.params); }` with `OpenUILibrary({..., List<ActionDef> actions = const []})`, and custom-action validation in the evaluator: a custom action whose evaluated argument fails its `ActionDef` type, or has a missing required argument, evaluates to null and adds a `runtime-error` (the whole action is a no-op, matching the React rule), and `prompt()` lists declared custom actions.

- [ ] **Step 1: Write the failing test**

```dart
test('extend replaces a component and prompt lists custom actions', () {
  final lib = openUIMvpLibrary().extend(
    components: [const ComponentDef('Text', 'Replaced.', [PropDef('text', PropType.string, required: true)])],
    actions: [const ActionDef('Share', 'Share it', [PropDef('id', PropType.string, required: true)])],
  );
  expect(lib.byName['Text']!.description, 'Replaced.');
  expect(lib.prompt(), contains('Share('));
});
test('custom action with wrong argument type is a no-op', () {
  // Parse a Button whose action is @Share(42) against a library where
  // Share requires a string id; expect: the Button's action prop is null
  // and errors contain 'runtime-error'.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/flutter/bin/flutter test test/library_api_test.dart`
Expected: FAIL with "extend isn't defined" (or prompt does not contain the custom action).

- [ ] **Step 3: Implement `extend`, prompt options and `ActionDef` validation**

`extend` returns a new `OpenUILibrary` (never mutates the receiver). Prompt options prepend `preamble`, append `additionalRules` and `examples` verbatim, and omit the built-in function section when `includeBuiltins` is false. Task 1's registry builders supplied through `extend(builders: ...)` are stored on the library so `OpenUIRenderer(library: extendedLib)` works without a separate registry argument.

- [ ] **Step 4: Run test to verify it passes**

Run: `~/flutter/bin/flutter test test/library_api_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/lang.dart lib/src/library.dart test/library_api_test.dart
git commit -m "feat: library extend, prompt options and custom actions"
```

### Task 4: Lang and renderer parity gaps

**Files:**
- Modify: `lib/src/lang.dart`, `lib/src/renderer.dart`
- Test: `test/lang_parity_test.dart`

**Interfaces:**
- Consumes: `ParseResult`, `StreamingParser`, `OpenUIController` (Task 2), `ComponentRegistry` (Task 1).
- Produces: `StoredMessage parseStoredMessage(String text, OpenUILibrary library, {Map<String, Object?> state = const {}, Map<String, Object?> queryData = const {}})` where `class StoredMessage { const StoredMessage({required this.prose, required this.result, required this.formState}); final String prose; final ParseResult result; final Map<String, Object?> formState; }` (parses `]]>openui:content` prose plus fenced programs with last-program-wins, and `]]>openui:context` JSON whose `formState` map is returned), `OpenUIRenderer({..., void Function(List<OpenUIError>)? onParseResult, void Function(OpenUIError)? onError})` (onParseResult fires once when streaming ends, onError fires for non-warning errors at that same point, never per-frame during streaming), Modal rendered as a real dialog (tap/presence rule: a Modal node renders an `AlertDialog` via `showDialog` on first build when it is in the tree, with a close action that removes it from view for that render), EditableTable cells bound to form state under key `"<statementId>:<columnLabel>:<row>"` when a `bind` prop is present (cells without `bind` keep the current local-only behaviour), and a Query-error view: when a Query has failed and has no data and no initial value, its dependent component renders `theme.errorBuilder` if supplied, otherwise a `Text` reading `数据加载失败：<tool>` (and `onToolError` still fires exactly once per failed fetch).

- [ ] **Step 1: Write the failing test**

```dart
test('stored message restores form state and last program wins', () {
  // Input: prose, a first fenced program, a second fenced program, and
  // a context block with {"formState": {"city": "Tokyo"}}.
  // Expect: result.root is from the second program, formState['city'] is 'Tokyo'.
});
testWidgets('failed Query shows error view and @Run retries it', (tester) async {
  // toolProvider throws once then succeeds; pump, expect error text,
  // tap a Button with @Run(tickets), pump, expect data text.
});
testWidgets('Modal opens as a dialog', (tester) async {
  // Pump a root containing a Modal; expect: find.byType(AlertDialog) finds one.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/flutter/bin/flutter test test/lang_parity_test.dart`
Expected: FAIL with "parseStoredMessage isn't defined" (and Modal renders as a Card, not a dialog).

- [ ] **Step 3: Implement stored-message parsing, parse-result callbacks, dialog Modal, bound EditableTable and the Query-error view**

Stored-message parsing reuses the existing marker skipping, but instead of discarding context JSON it decodes it with `dart:convert` and extracts `formState` if it is a map. The existing streaming rule is preserved: a half-written Query line never triggers a tool call (see Review Focus). The dialog Modal must not re-open on every rebuild: guard with a per-statement flag in renderer state that resets only when the Modal node leaves the tree.

- [ ] **Step 4: Run test to verify it passes**

Run: `~/flutter/bin/flutter test test/lang_parity_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/lang.dart lib/src/renderer.dart test/lang_parity_test.dart
git commit -m "feat: stored messages, parse callbacks, dialog Modal, bound EditableTable, Query error view"
```

### Task 5: Hand primitives (skeleton, citations, sources)

**Files:**
- Create: `lib/src/primitives.dart`
- Modify: `lib/src/renderer.dart`, `lib/openui_flutter.dart`
- Test: `test/primitives_test.dart`

**Interfaces:**
- Consumes: `OpenUIThemeData` (Task 2).
- Produces: `class Skeleton extends StatelessWidget { const Skeleton({this.count = 3}); }`, `class TableSkeleton extends StatelessWidget { const TableSkeleton({this.columns = 3, this.rows = 4}); }`, `class Citation extends StatelessWidget { const Citation({required this.index, required this.title, this.url}); }` (renders `[n]` chip; tap calls the supplied `onTap` if given, otherwise does nothing), `class Sources extends StatelessWidget { const Sources({required this.items}); }` where an item is `({String title, String? url, String? faviconUrl})` (render as a row with favicon image when `faviconUrl` is present, title text, and a tap that does nothing unless the host supplies a handler through the theme's link handler — see Task 2's theme, extended here only if needed), and renderer wiring: a Table whose columns have no rows while its Query is loading renders `TableSkeleton` instead of an empty table.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('TableSkeleton shows while a Table Query loads', (tester) async {
  // Pump a Table whose Col values come from a Query with no initial
  // value and a toolProvider that never completes (Completer).
  // Expect: find.byType(TableSkeleton) finds one, and no DataTable.
});
testWidgets('Citation renders [n] and Sources renders titles', (tester) async {
  // Pump Citation(index: 2, title: 'Doc') and Sources with two items.
  // Expect: finds '[2]' and both titles.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/flutter/bin/flutter test test/primitives_test.dart`
Expected: FAIL with "TableSkeleton isn't defined".

- [ ] **Step 3: Implement the primitives and the Table loading rule**

Skeleton bars use the theme's surface colour at low opacity when a theme is available, otherwise `Colors.grey.shade300` as today. Do not change the existing generic `_Skeleton` behaviour for other loading components.

- [ ] **Step 4: Run test to verify it passes**

Run: `~/flutter/bin/flutter test test/primitives_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/primitives.dart lib/src/renderer.dart lib/openui_flutter.dart test/primitives_test.dart
git commit -m "feat: skeleton, TableSkeleton, citation and sources primitives"
```

### Task 6: Extra charts (heatmap, funnel, calendar heatmap, mini, legend, condensed)

**Files:**
- Create: `lib/src/extra_charts.dart`
- Modify: `lib/src/library.dart`, `lib/src/renderer.dart`, `lib/openui_flutter.dart`
- Test: `test/extra_charts_test.dart`

**Interfaces:**
- Consumes: `Series`, `Slice` nodes (existing), `OpenUIThemeData.chartPalette` (Task 2).
- Produces: new library components `HeatmapChart(categories: list, series: nodes)`, `FunnelChart(slices: nodes)`, `CalendarHeatmap(values: list)` where `values` is a list of `{date: string, value: number}` maps, `MiniBarChart(values: list)`, `MiniLineChart(values: list)`, `StackedLegend(series: nodes)` (renders palette swatches with labels, no chart area), and condensed variants `BarChartCondensed`, `LineChartCondensed`, `AreaChartCondensed` (same props as their full versions, fixed height 120, no legend row).

- [ ] **Step 1: Write the failing test**

```dart
test('extra chart components are in the library', () {
  final names = openUIMvpLibrary().components.map((c) => c.name).toSet();
  expect(names, containsAll(['HeatmapChart', 'FunnelChart', 'CalendarHeatmap', 'MiniBarChart', 'MiniLineChart', 'StackedLegend', 'BarChartCondensed']));
});
testWidgets('funnel and heatmap render without crashing', (tester) async {
  // Pump a root with a FunnelChart of three slices and a HeatmapChart.
  // Expect: pumpAndSettle completes and the funnel slice labels are found.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/flutter/bin/flutter test test/extra_charts_test.dart`
Expected: FAIL with "HeatmapChart not in library" (unknown-component).

- [ ] **Step 3: Implement the extra charts with CustomPainter**

Heatmap: grid cells coloured by value/max with the first chart-palette colour at increasing opacity. Funnel: centred trapezoids narrowing by value. CalendarHeatmap: 7-row week grid, cell opacity by value/max, no date arithmetic beyond parsing `yyyy-MM-dd` with `DateTime.parse` and weekday. Mini charts: same painters as bar/line at height 48 with no axes or legend. Condensed charts reuse the existing `_ChartWidget` with a height parameter of 120 and legend hidden.

- [ ] **Step 4: Run test to verify it passes**

Run: `~/flutter/bin/flutter test test/extra_charts_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/extra_charts.dart lib/src/library.dart lib/src/renderer.dart lib/openui_flutter.dart test/extra_charts_test.dart
git commit -m "feat: heatmap, funnel, calendar heatmap, mini charts, stacked legend, condensed charts"
```

### Task 7: AgentInterface shell, part 1 (model, storage, threads, composer)

**Files:**
- Create: `lib/src/agent/agent_storage.dart`, `lib/src/agent/agent_interface.dart`
- Modify: `lib/openui_flutter.dart`
- Test: `test/agent_test.dart`

**Interfaces:**
- Consumes: `OpenUIController` (Task 2), `OpenUIRenderer` (existing).
- Produces: `abstract class AgentStorage { Future<List<AgentThread>> listThreads(); Future<AgentThread?> loadThread(String id); Future<void> saveThread(AgentThread thread); Future<void> deleteThread(String id); }`, `class AgentThread { const AgentThread({required this.id, required this.title, required this.messages}); }`, `class AgentMessage { const AgentMessage({required this.role, required this.text, this.openUiResponse}); }` (`role` is `'user'` or `'assistant'`), `abstract class AgentLlm { Stream<String> send(List<AgentMessage> history, String prompt); }` (the host implements this against its own model provider; the shell never calls a model API directly), and `class AgentInterface extends StatefulWidget { const AgentInterface({required this.storage, required this.llm, this.library, this.toolProvider, this.onAction}); }` rendering, in this task: a sidebar thread list (tap switches thread, delete removes it), a thread header (title, rename via a text field, delete), a welcome empty state when no thread is selected, and a composer (text field + send button; send appends a user message, streams the LLM response into an `OpenUIRenderer` via the controller, and saves the thread).

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('AgentInterface lists threads, switches, and sends a message', (tester) async {
  // Fake storage with two threads, fake LLM that streams 'root = TextContent("hi")'.
  // Expect: thread titles found; tap second thread, its messages shown;
  // type in composer, tap send, expect the user text and the streamed
  // assistant UI text found, and storage.saveThread called.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/flutter/bin/flutter test test/agent_test.dart`
Expected: FAIL with "AgentInterface isn't defined".

- [ ] **Step 3: Implement the shell part 1**

Layout: `Row` with a fixed-width sidebar (280) on wide screens and a drawer-style fallback is out of scope for this task (note it in the test file comment); on narrow screens the sidebar is hidden behind a menu button that opens it as a drawer. Do not implement Workspace, Artifact or ToolCall in this task. The composer disables send while the LLM stream is active.

- [ ] **Step 4: Run test to verify it passes**

Run: `~/flutter/bin/flutter test test/agent_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/agent/agent_storage.dart lib/src/agent/agent_interface.dart lib/openui_flutter.dart test/agent_test.dart
git commit -m "feat: AgentInterface shell part 1 (threads, composer)"
```

### Task 8: AgentInterface shell, part 2 (slots, workspace, artifact, tool calls)

**Files:**
- Create: `lib/src/agent/agent_slots.dart`, `lib/src/agent/agent_tools.dart`
- Modify: `lib/src/agent/agent_interface.dart`
- Test: `test/agent_test.dart` (extend, same file)

**Interfaces:**
- Consumes: `AgentStorage`, `AgentLlm`, `AgentThread`, `AgentMessage` (Task 7), `OpenUIController` (Task 2).
- Produces: `class AgentSlots { const AgentSlots({this.sidebar, this.sidebarHeader, this.sidebarFooter, this.mobileHeader, this.threadHeader, this.welcome, this.composer, this.workspace}); }` where each field is a `Widget Function(BuildContext, AgentInterfaceState)?` (null means the default for that area), `class AgentInterfaceState { AgentThread? get currentThread; bool get isStreaming; }` (exposed to slot builders), `class AgentToolCall { const AgentToolCall({required this.tool, required this.params, this.result, this.status = 'running'}); }` (`status` is `'running'`, `'done'` or `'error'`), `class AgentArtifact { const AgentArtifact({required this.id, required this.title, required this.content}); }`, and `AgentInterface({..., AgentSlots? slots, List<AgentToolCall> Function()? toolCalls, List<AgentArtifact> Function()? artifacts})` rendering: a workspace column on the right when artifacts are present (tap an artifact to show its content), and a tool-call timeline above the assistant message (each call shows tool name, status icon, and result text when done).

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('AgentInterface slots override defaults and tool timeline shows', (tester) async {
  // Slots with a custom welcome widget; toolCalls returning one done call.
  // Expect: custom welcome text found (not the default), tool name and
  // result text found in the timeline.
});
testWidgets('AgentInterface workspace shows artifact content on tap', (tester) async {
  // artifacts returning one artifact; tap its title; expect its content found.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/flutter/bin/flutter test test/agent_test.dart`
Expected: FAIL with "AgentSlots isn't defined" (and the new tests fail while the Task 7 tests still pass).

- [ ] **Step 3: Implement slots, workspace, artifact and tool timeline**

Slot rule (React parity): a slot builder, when supplied, replaces that area entirely; when absent, the Task 7 default renders. Tool calls and artifacts are read-only views in this task: the shell does not execute tools itself, it displays what the host's `toolProvider` (Task 2) already ran, via the host-supplied lists.

- [ ] **Step 4: Run test to verify it passes**

Run: `~/flutter/bin/flutter test test/agent_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/agent/agent_slots.dart lib/src/agent/agent_tools.dart lib/src/agent/agent_interface.dart test/agent_test.dart
git commit -m "feat: AgentInterface slots, workspace, artifact, tool timeline"
```

### Task 9: Example app, docs and migration guide

**Files:**
- Modify: `example/lib/main.dart`, `README.md`
- Create: `docs/superpowers/specs/2026-10-28-openui-flutter-sdk-design.md` (copy of the brainstorm scheme, updated to match the shipped API names)
- Test: `test/conformance_test.dart` (scaffolding only in this task: one test per example screen that pumps it without crashing)

**Interfaces:**
- Consumes: everything from Tasks 1–8.
- Produces: an example app with four screens (chat rich answer, dashboard, form + Query, custom component + theme switch), a README section per new API with a code snippet, and a migration guide section (old `OpenUIRenderer(response: ...)` to controller mode, `openUIMvpLibrary` to `openUIStandardLibrary()` added in Task 3).

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('example screens pump without crashing', (tester) async {
  // Pump each example screen widget (extracted as testable widgets in
  // example/lib, not only in main()).
  // Expect: pumpAndSettle completes for each.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/flutter/bin/flutter test test/conformance_test.dart`
Expected: FAIL with "example screen widget isn't defined" (or the screens do not exist yet).

- [ ] **Step 3: Implement the example screens, README sections and migration guide**

Example screens must use only public API (no `src/` imports). The custom-component screen is the acceptance demo for Task 1: a host-defined component rendered inside a standard library root.

- [ ] **Step 4: Run test to verify it passes**

Run: `~/flutter/bin/flutter test test/conformance_test.dart && ~/flutter/bin/flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add example/lib/main.dart README.md docs/superpowers/specs/2026-10-28-openui-flutter-sdk-design.md test/conformance_test.dart
git commit -m "docs: example app, SDK docs and migration guide"
```

### Task 10: Conformance, golden tests and pub.dev readiness

**Files:**
- Modify: `test/conformance_test.dart` (extend), `pubspec.yaml`, `CHANGELOG.md` (create)
- Test: `test/conformance_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–9.
- Produces: conformance tests that run the same OpenUI Lang programs used in the React docs examples (card + bar chart + form + tabs; Query weather example `Query("get_weather", {"city": "Tokyo"}, {})` with a fake provider; Mutation retry example `Mutation("retry_deployment", {"project": "prod"})`) and assert the same visible texts and counts the React renderer would show, golden tests for one chart and one card (recorded with `flutter test --update-goldens` once, then asserted on every run), a `CHANGELOG.md` with a 1.0.0 entry listing every breaking change from the old API, and a pubspec version of `1.0.0` with a correct description and repository/homepage fields (homepage is left as a placeholder the user must fill before publishing — the task must not invent a URL).

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('conformance: weather Query example shows forecast data', (tester) async {
  // Fake provider returns Tokyo weather rows; program uses Query +
  // @Count/@Filter as in the React docs example.
  // Expect: the count text and a filtered row label are found.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/flutter/bin/flutter test test/conformance_test.dart`
Expected: FAIL (conformance programs not yet covered, or golden files missing).

- [ ] **Step 3: Implement conformance tests, record goldens, write CHANGELOG and bump to 1.0.0**

Golden files live under `test/goldens/` and are committed in this task. Do not publish to pub.dev in this task: publishing needs the user's pub.dev account and homepage URL, which this plan deliberately leaves as a manual step.

- [ ] **Step 4: Run test to verify it passes**

Run: `~/flutter/bin/flutter test && ~/flutter/bin/flutter analyze`
Expected: PASS, no issues, full suite green.

- [ ] **Step 5: Commit**

```bash
git add test/conformance_test.dart test/goldens/ pubspec.yaml CHANGELOG.md
git commit -m "chore: conformance, goldens and 1.0.0 readiness (no publish)"
```

---

## Self-Review

- **Spec coverage:** GenUI 86 already shipped (not re-planned). Lang parity (Task 4), library API (Task 3), hand primitives (Task 5), extra charts (Task 6), AgentInterface (Tasks 7–8), SDK modularity (Tasks 1–2, 9), publishing readiness (Task 10) each map to a task. Gateway/Autofix are explicitly out of scope (Global Constraints) because they are server services, not Flutter code.
- **Step scan:** Each step names one test, one command with expected output, or one signature. Task 4's Modal dialog rule and Task 8's slot rule are the only behavioural rules not fully determined by a signature, and both are pinned by their tests.
- **Type consistency:** `ComponentRegistry` (Task 1) is consumed by Task 2's controller and Task 3's `extend(builders:)` with the same `OpenUIComponentBuilder` typedef. `OpenUIThemeData` (Task 2) is consumed by Tasks 5 and 6. `AgentStorage`/`AgentLlm` (Task 7) are consumed unchanged by Task 8. `StoredMessage` (Task 4) is a new class, not a tuple, so later tasks can import it by name.
- **Review Focus:** All five lines have owning tests: custom-component nesting (Task 1), Query failure + `@Run` retry (Task 4), half-written Query (Task 4, preserving the existing rule), parameter-change refetch (Task 2's controller tests, extended in Task 4), stored-message restore (Task 4).
- **Proportion:** This plan is a decision document, not code: it names files, signatures and tests, and leaves bodies to the implementer. Task 7–8 are the largest because AgentInterface is a whole app shell, not a single component.
