# Changelog

## Unreleased

- React 0.18.1 full alignment (general library): `IconText` and
  `IconButton` `icon` accept an Icon node (React Icon ref) as
  well as the string name shorthand, completing the icon-ref
  alignment started with `Tag`/`ChipItem`; chart `series` /
  `datasets` / `points` accept plain objects (React's
  SeriesSchema / ScatterSeriesSchema / PointSchema) as well as
  nodes — maps are normalized to synthetic nodes at the renderer
  boundary, so the fl_chart widgets are unchanged. README
  dependency statements corrected to the actual pubspec
  (flutter_markdown_plus + fl_chart, no self-drawn charts left)
  and the pubspec description no longer claims 9 extra charts.
- React 0.18.1 full alignment (general library), feature
  completion: `DatePicker` `mode` `"range"` now uses
  `showDateRangePicker` and stores a `{from, to}` map of
  yyyy-MM-dd strings, mirroring React's DateRange value shape;
  `Tag` and `ChipItem` `icon` accept an Icon node (React's Icon
  ref, with its name and category fallback) as well as the string
  name shorthand; pie/radial/single-stacked charts read Slice
  nodes from `labels` when `values` is absent (React's
  buildSliceData fallback) — which also makes `values` optional
  on those three charts, since the fallback was previously
  unreachable behind the required-values check.
- React 0.18.1 full alignment (general library): props that were
  accepted with no visible effect now do what React does — `Icon`
  `category` picks the fallback icon when the name does not resolve
  (lucide kebab-case names are normalized first); `Separator`
  `decorative` hides the divider from assistive tech; `Point` `z`
  scales the scatter bubble radius; `EntityList` `rightVariant`
  `"number"` renders the trailing value in tabular figures;
  card-block `responsive` switches the grid between container
  breakpoints (1 column under 480, 2 under 768, balanced rows
  above, porting React's getRowConfiguration); `bgImageAlt` is the
  background image's semantic label; `Select` without a placeholder
  shows `"Select..."` as React does. The stale "accepted but no
  visible effect" comments are updated, and the card-block grid
  test now sets the viewport width (a SizedBox cannot shrink
  below the scroll viewport's width).

- BREAKING, React 0.18.1 full alignment (general library): `Text` /
  `BoldText` now use React's schema order, `variant` (default
  `"text"`) first and `value` second — the order React has used
  since these components appeared (0.16-0.18, zod key order).
  Programs must write `Text("text", "...")`; a one-arg call now
  binds to `variant`. All in-repo programs and tests migrated.
- BREAKING, React 0.18.1 full alignment (general library): the 9
  Flutter-only chart names are deleted — `HeatmapChart`,
  `FunnelChart`, `CalendarHeatmap`, `MiniBarChart`, `MiniLineChart`,
  `StackedLegend`, `BarChartCondensed`, `LineChartCondensed`,
  `AreaChartCondensed` (the condensed files in React register as
  `BarChart`/`LineChart`/`AreaChart`, which this port already has).
  Counts are now general 82, chat 84, union 86 — exactly React's
  0.18.1 registration. The example dashboard program and all tests
  that used the deleted names now use React charts.
- BREAKING, React 0.18.1 full alignment (general library): gap
  defaults and scale now match React (`--openui-space`: none 0,
  xs 6, s 8, m 12, l 18, xl 24, 2xl 36; Stack/Card absent gap falls
  back to "m" = 12, card-block absent gap to 12). Programs that
  relied on zero default spacing now get 12px; the card golden
  was regenerated for the new spacing.
- React 0.18.1 full alignment (general library): the mapper now
  enforces schema unions — card-block items min(2) and matching
  item types, Snippet layout grid-only (other values error and
  fall back to grid), the FormControl input whitelist (Input,
  TextArea, Select, DatePicker, Slider, CheckBoxGroup, RadioGroup,
  Chips, OptionCards), Form fields (FormControl only), Tabs/
  Accordion/Steps/Buttons item types, chart series/dataset/point
  types, and the content unions (TabItem/AccordionItem content,
  Modal children, Card children, Carousel slides). Violations in
  lists drop the item with a type-mismatch; a bad FormControl
  input or a short block drops the node. Content unions are
  general-library only (React's chat variants are wider); loading
  placeholders are never filtered. Tests that used 1-item blocks
  or SwitchGroup-in-FormControl now use React-valid programs.
- Token-level incremental parsing: `StreamingParser.push` no longer
  runs two full parses per chunk. Two `IncrementalOpenUIParser`
  instances (stable lines, display text) cache line parses by line
  text and statement evaluations by dependency: a push only parses
  new lines and re-evaluates statements whose dependencies changed
  (tracked edges cover forward references, redefinitions, variables
  and unresolved names). The standalone renderer uses the same
  parser across builds, so a growing response is parsed
  incrementally there too. Results match one-shot `parseOpenUI`
  exactly (roots, error multisets, unresolved sets, request sets;
  error order may differ). `IncrementalStats` (`parseCalls`,
  `linesParsed`, `freshEvaluations`) proves it: a 61-line program
  fed line by line parses 61 lines and evaluates ~121 statements,
  not 61 x 61. Form state / Query data / failure changes still
  re-evaluate everything (line parses reused), since any value could
  depend on them.
- Library split, as in React: `openUIStandardLibrary()` is now the
  general library (root `Stack`, 91 names) and `openUIChatLibrary()`
  is the chat library (root `Card`, 93 names: everything except
  `Stack`/`Modal`, with the chat `Card` variant). The union is the
  full 95. Membership is enforced by the parser (`unknown-component`).
  Tabs/Accordion/Carousel share one definition across both libraries:
  React's chat variants differ only in content unions, which this
  port's mapper does not enforce. SectionBlock/SectionItem corrected
  to the React shapes (`sections`/`isFoldable?`,
  `value`/`trigger`/`content`); foldable sections render as
  expansion tiles.
- Chat Card sources: the chat `Card` takes `sources?`
  ([{title, sourceName?, url?}]), rendered as a Sources strip below
  the card; inline [n] citations in TextContent descendants link to
  them (tappable, dispatching `OpenUrl`; out-of-range markers and
  url-less sources stay plain text; the innermost Card wins for
  nested cards). The general Card has no sources prop.
- Rules validation engine: `validateRules(rules, value)` implements
  required/email/url/numeric/min/max/minLength/maxLength/pattern
  (empty values skip all checks except required; lists apply
  min/max/numeric to the first element). FormControl shows the live
  error under touched inputs only (touched = the name key exists in
  form state); there is no submit gate — hosts call `validateRules`
  directly for submit-time validation.
- EditableTable restructured to the React schema: `name?`/`columns?`/
  `data?` (column objects `{type: text/number/date-single/select/url,
  key?, header?, width?, options?}`, row objects `{id, values}`).
  Cell edits write to form state under `<name>:<rowId>:<columnKey>`
  (statement id when name is empty); "Save Changes" writes the full
  edited rows under `name` (skipped when name is empty). The old
  Col-nodes + `bind` shape is removed. Cell editors follow the column
  type: number keyboard with numeric parsing, select dropdown,
  date-single date picker, url keyboard.
- Props Batch C (Form family, from the schema-level diff against
  @openuidev/react-ui 0.18.1) — BREAKING for programs using the old
  form props: `Form` is now `name`/`buttons`/`fields?` (no `children`);
  `FormControl` is `label`/`input`/`hint?` (one input node, no
  `children` list); inputs are keyed by `name` instead of `bind`
  (`Input` `name`/`placeholder?`/`type?`/`rules?`/`value?`,
  `TextArea` adds `rows?`, `Select` renames `options` to `items` and
  adds `size?`, `SelectItem`/`ChipItem`/`OptionCard` are value-first,
  `DatePicker` adds `mode?`, `Slider` requires `variant`/`min`/`max`
  with no defaults and takes an array `value`, `CheckBoxItem`/
  `RadioItem`/`SwitchItem` take `label`/`description`/`name` (or
  `value`), groups take record/string state under `name`, `Chips`
  defaults to `multiple` and `OptionCards` to `single`, `OptionCard`
  is `value`/`title`/`subtitle?`/`topContent?`/`disabled?`).
  Documented deviations: the FormControl input union is not enforced
  by the mapper (any node is accepted, so SwitchGroup still renders
  inside FormControl even though React excludes it); DatePicker
  `mode` range renders as the single-date picker; ChipItem `icon`
  stays a string name, not an Icon ref; `rules` are accepted and
  stored but only `rules.required` has a visible effect (a " *"
  marker on the FormControl label) — no validation engine is built.
  The public group/field widgets in extra_widgets.dart rename their
  `bind` parameter to `stateKey`.
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
  "m" fallback). EditableTable props are unchanged (later batch).
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
