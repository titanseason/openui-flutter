# Changelog

## Unreleased

- Props Batch B (card blocks, from the schema-level diff against
  @openuidev/react-ui 0.18.1): all 10 card-block components now follow
  the React schemas — blocks take `items`/`layout?`/`responsive?`/
  `action?`/`gap?` (no `title`); items take node refs, e.g.
  SnippetCardItem `id?`/`lhs`/`rhs?`, OverviewCardItem `id?`/`top`/
  `bottom?`, ContextCardItem `id?`/`title` (string or Tag node)/
  `body?`/`bgColor?`/`bgImageSrc?`/`bgImageAlt?`, CompositeCardItem
  `id?`/`header?`/`body?`/`footer?`, VisualCardItem `body` (BoldText)/
  `id?`/`bgImageSrc?`/`tag?`/`bgImageAlt?`. Documented deviations:
  items `.min(2)` not enforced; `responsive` accepted with no visible
  effect; absent `gap` defaults to 8px; SnippetCardBlock `carousel`
  falls back to grid (its schema is grid-only); bg image is decorative
  with a translucent scrim, `bgImageAlt` not surfaced.
- Props Batch A (from the schema-level diff against @openuidev/react-ui
  0.18.1): layout, content, Col, charts, data-display, actions,
  dialogue and host-primitive props now follow the React schemas —
  e.g. charts take `labels` (not `categories`), `Series` takes
  `category`, `PieChart`/`RadialChart`/`SingleStackedBarChart` take
  `labels` + `values` arrays (not Slice nodes), `CodeBlock` is
  `language`-first, `Callout` is `variant`/`title`/`description`/
  `visible`, `TabItem`/`AccordionItem` are `value`/`trigger`/`content`,
  `Tag` is `text`/`icon?`/`size?`/`variant?`, `EntityList` takes row
  objects, metrics take `value`/`subtext?`/`trend?`, `IconButton` is
  `name`-first, `Skeleton` defaults to count 1 and `TableSkeleton` to
  5×4. Documented deviations: `Text`/`BoldText` put `value` first
  (schema order would bind a one-arg call to `variant`); icon props
  stay string names, not Icon refs; the chat `Card` sources variant
  is skipped; `Stack`/`Card` gap defaults to no spacing (not React's
  "m" fallback). Form family, card blocks and EditableTable props are
  unchanged (later batches).
- Component names aligned directly with @openuidev/react-ui 0.18.1 (from
  the schema-level diff, see docs/react-1.0-diff/) — BREAKING for
  programs using the old short names: `MarkdownRenderer` is now
  `MarkDownRenderer`, and `SnippetBlock`/`SnippetItem`,
  `OverviewBlock`/`OverviewItem`, `ContextBlock`/`ContextItem`,
  `CompositeBlock`/`CompositeItem`, `VisualBlock`/`VisualItem` are now
  the `*CardBlock`/`*CardItem` pairs. No short-name aliases are kept;
  the library is back to 95 registered names over 95 components.
  Name alignment is names only: components still accept this library's
  props, not the official Zod schema's props (e.g. MarkDownRenderer
  takes `text` here, React's schema takes `textMarkdown`).

## 1.0.0 — 2026-10-28

First stable release: a pure-Dart OpenUI Lang parser/evaluator plus a
Flutter renderer for the full 86-component GenUI library (plus 9 extra
charts/legends), a registry/controller/theme/library API, and the
AgentInterface chat shell. Not yet published to pub.dev: publishing
needs the package owner's pub.dev account, and the repository/homepage
URLs in pubspec.yaml are still placeholders under `.invalid` — replace
them with the real repository before publishing. `dart pub publish
--dry-run` additionally reports a missing LICENSE file in the package
root: the license choice is the owner's decision and is deliberately
not picked here — add a LICENSE file before publishing.

### Breaking changes from the pre-1.0 API

- `openUIMvpLibrary()` is now `@Deprecated` — use
  `openUIStandardLibrary()` (identical result). The alias still works.
- `openUIMvpLibrary()` no longer returns just the original 25-component
  MVP set: since the library-API work it returns the full library
  (86 GenUI + 9 extra components).
- Charts are rendered with fl_chart, not the original self-drawn
  painters (same component names and props, different pixels).
  HeatmapChart, FunnelChart and CalendarHeatmap stay self-drawn.
- `Modal` is now a real `AlertDialog`, not an inline titled card
  (reopens on a replacement statement, does not reopen after close).
- `lang.dart` is no longer importable from a pure-Dart package: the
  parse/eval logic uses no Flutter API, but the file imports
  `registry.dart` for the library registry field.
- Minimum versions raised: Flutter `>=3.27.4` and Dart SDK `^3.6.2`
  (both fl_chart 1.3.0's floor; the declared floors now match).
- Third-party dependencies are now two, not zero:
  flutter_markdown_plus 1.0.12 and fl_chart 1.3.0. `CodeBlock` is
  plain monospace text — no syntax-highlighting dependency.

### Added since the pre-1.0 baseline

- Component registry with per-component builder override
  (`ComponentRegistry`, `OpenUIRenderer(registry: ...)`).
- `OpenUIController` (controller mode wins over old renderer
  parameters) and `OpenUIThemeData` (light/dark, chart palette,
  skeleton/error builders).
- Library API: `extend()` (replace/add/remove components, functions,
  actions, builders), `prompt()` options, custom actions with
  validation, `ActionDef`.
- Stored-message parsing (`StoredMessage`, `parseStoredMessage`),
  renderer `onParseResult`/`onError` callbacks, bound `EditableTable`
  (`bind`), Query failure UI with `@Run` retry.
- Hand primitives: `Skeleton`, `TableSkeleton`, `Citation`, `Sources`;
  a Table whose Query is loading renders `TableSkeleton`, and a
  failed Query inside Table columns surfaces the error.
- Extra charts: `HeatmapChart`, `FunnelChart`, `CalendarHeatmap`,
  `MiniBarChart`, `MiniLineChart`, `StackedLegend`,
  `BarChartCondensed`, `LineChartCondensed`, `AreaChartCondensed`.
- AgentInterface shell: `AgentStorage`, `AgentThread`, `AgentMessage`,
  `AgentLlm`, thread list/header/welcome/composer with streaming,
  `AgentSlots` (8 slots), workspace/Artifact panel, read-only
  ToolCall timeline. The shell never executes tools or calls an LLM
  API itself.
- Example app (`example/`, 4 screens), migration guide, conformance
  tests (React-docs programs) and golden tests (`test/goldens/`).

### Known limitations (not fixed in 1.0.0)

- Parsing is full re-parse per push plus last-line autoclosing;
  token-level incremental parsing is not implemented.
- Component props are not yet aligned 1:1 with the official React
  props; the library defines one representative prop per intent.
- Golden files are recorded on this host's font stack and may need
  re-recording on other platforms.
- The Task 6 visual checks (HorizontalBarChart rotated title
  placement, 2-category RadarChart padded triangle) are covered by
  widget tests and the example dashboard screen, but still need a
  human eye on a real device.
- Gateway/Autofix are out of scope: they are server services, not
  Flutter code.
