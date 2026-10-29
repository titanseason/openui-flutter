# Changelog

## Unreleased

- License: Apache License 2.0 (`LICENSE`, copyright 2026
  titanseason). This clears the license item from the
  pre-publish checklist; repository/homepage URLs and the
  pub.dev account are still pending.
- Renderer dispatch is now a registry: the built-in component
  switch is replaced by a `_builtinBuilders` map (73 names → 68
  functions; Text/BoldText share one, the five card blocks share
  one). Builders take a `RendererContext` facade (theme, form
  state, dispatch, child rendering, shared helpers); the custom
  registry still wins over the built-in map, and unknown names
  still render empty. No behavior change: all tests and goldens
  pass unchanged.
- Docs: README rewritten in English (default) with a Chinese
  mirror (`README.zh-CN.md`); the old README described the
  removed chat module and 86 components. The pubspec
  description now says 82 components as well.
- All code comments are English (verified by scan; the one
  remaining Chinese comment was translated, the rest of the
  Chinese text in the tree is runtime UI strings and test data).
- Directory layout: `lib/src` is now grouped by layer —
  `core/` (Lang, library, registry), `runtime/` (controller,
  renderer, theme), `widgets/` (primitives, extra widgets),
  `charts/` (unchanged). Public imports are unaffected: only
  the package barrel changed.
- **Breaking: the chat module is removed.** Deleted:
  `openUIChatLibrary()` and the chat `Card` variant, the
  chat-only components (`FollowUpBlock`, `FollowUpItem`,
  `SectionBlock`, `SectionItem`), the `AgentInterface` shell
  and its slots/storage/tool-call types, `StoredMessage` and
  `parseStoredMessage`, and the Card sources strip with its
  inline `[n]` citation backing in `TextContent`. The single
  remaining library is `openUIStandardLibrary()` (82 names,
  root `Stack`). The standalone `Citation`/`Sources` widgets
  stay: they are generic UI, usable by any host directly.
- Semantic theme board: `OpenUIColorScheme` gains `textMuted`,
  `border`, `grid`, `success`, `warning`, `danger`, and `info`
  (light defaults reproduce the previously hardcoded greys and
  Callout colours exactly, so existing goldens are unchanged;
  dark values are lighter chrome for dark surfaces). Charts
  take their axis text, gridlines, tracks, box borders, and
  tooltip borders from the theme via a new `ChartColors`
  bundle bridged by the renderer; Callout variants take their
  colours from the same scheme. Hover highlight overlays and
  the tooltip card fill stay as before (translucent grey and
  a light card). New dark bar golden pins the dark chrome.

- Chart layout props (React parity): Bar/Line/Area charts
  accept `density` (compact 48 / default 72 / spacious 96px
  slots, scroll mode only), `condensed` (fit mode: every
  category shares the container width, no scrolling, labels
  thinned when narrower than 40px + gap and truncated with
  an ellipsis), and `tickVariant` (singleLine / multiLine /
  angled; angled rotates labels -45 degrees and is
  condensed-only — in scroll mode it falls back to
  singleLine, and narrow containers under 300px force
  singleLine). Lang passes them positionally after `height`
  (BarChart's def order is labels, series, variant, xLabel,
  yLabel, height, density, condensed, tickVariant).
  Horizontal bars are untouched: React's horizontal path
  never reaches the cartesian layout, so these props are
  inert there too.
- Chart axis ticks (React parity): all axis tick labels —
  vertical Y axes, scatter numeric axes, and the horizontal
  bar value strip — now use React's numberTickFormatter
  (K/M/B/T abbreviation at 1e3/1e6/1e9/1e12, 1 decimal below
  10 units, none at 10 and above, 2 decimals for
  non-integers below 1000), including the axis width
  measurement. Tooltips keep their own formatter. Existing
  goldens are unaffected (their ticks are small integers).
- Chart calibration (React parity, Phase 4): line/area variant
  now defaults to natural (was linear when Lang omitted
  variant), both in the renderer and in LineChartWidget's own
  default; static dots are off by default (React showDots =
  false, dotRadius 3 when enabled) with the hovered active dot
  unchanged; bar corner radius 6 -> 4 (React barRadius); radar
  grid goes from 4 to 5 levels (React gridLevels) and the
  default radar variant is line (outline only, area fill is
  now opt-in via an `area` flag — Lang's RadarChart exposes no
  variant); pie slices no longer carry white on-slice titles
  (React has none, labels live in the legend and tooltip);
  tooltip numbers follow React's formatter (thousands
  separators below 100000, K/M/B/T abbreviation floored to 1
  decimal at and above it; scatter coordinates group without
  abbreviating). All chart widgets gain an `onTap` callback
  (React's onClick, direct-widget users only — Lang cannot
  express callbacks): category index for bar/line/radar,
  slice/ring/segment index for pie/radial/stacked, and
  (series, point) for scatter. Tap detection uses raw pointer
  events, not a tap recognizer, because the tap recognizer
  starves touch-drag tooltips; a drag still never fires a tap.
  New line and radar goldens pin the curve default, the
  dot-less line, the 5 radar rings and the unfilled radar;
  the bar golden was regenerated for radius 4.
- Scrolling cartesian charts and multi-line X labels (React
  parity, Phase 3c): when categories no longer fit at React's
  72px default slot width, the plot scrolls horizontally (rows
  vertically for horizontal bars) behind snap-to-category
  scroll buttons below the plot, while the Y axis (or the
  bottom value strip) stays fixed and the grid scrolls with
  the content. X labels wrap to at most 3 lines (at most half
  the chart height) with slots widening to at most 3x before
  scrolling kicks in, and narrow containers drop to a single
  line, all per React's x-axis layout rules. Line points now
  sit at slot centers (React's scalePoint, was plot edges),
  so the hovered point is the hovered slot. The bar golden
  was regenerated (same bars, label band 22px -> 30px).
- Charts moved to their own folder (`lib/src/charts/`, one file
  per chart type plus a shared `common.dart`, wired together as
  parts of `charts.dart`): no behavior change, all tests and
  goldens pass unchanged. The chart test moved to
  `test/charts/` alongside.
- Chart legends (React parity, Phase 3b): pie/radial now use the
  stacked legend — 32px rows with the label on the left and the
  share on the right, re-normalized over the visible slices at 1
  decimal, past 6 items behind "Show more"/"Show less", and
  hovering a row (or a slice/ring) highlights it and dims the
  rest. Series legends collapse by measured width behind a
  "N more" / "Show Less" toggle like React's DefaultLegend.
  Hidden rows dim to 0.3 (was 0.4).
- Single stacked bar is now a horizontal track (React parity,
  Phase 3a): 20px tall, full width, segments sized by share of
  total with 4px padding, 2px gaps, 2px minimum width and
  rounded outer corners, plus the centered 1px accent line.
  Hovering a segment or a legend row highlights it and dims the
  rest; there is still no legend toggle. The legend now shows
  label + percentage at 1 decimal, like React's DefaultLegend.
- Chart axes and negative values (React parity, Phase 2):
  vertical charts (bar, line, area) and the scatter chart now
  draw a value axis with horizontal gridlines and d3-style nice
  ticks (~1 per 40px, floored at 2); horizontal bars get the
  mirrored bottom value axis with vertical gridlines. Domains
  always run through zero (bar/line) and negatives render below
  (or left of) the baseline, with stacked bars using React's
  sign offset (positives up, negatives down) and rounded far
  ends. Area fills stop at the zero baseline. Scales still come
  from all series, hidden or not. The bar golden was regenerated
  (same bars, now with axis, grid, and a nice max of 25 instead
  of 24).
- Chart tooltips and legend toggles (React parity, Phase 1):
  hovering a chart shows a tooltip card (title + one row per
  series) and touch drag moves it; touch end hides it and a
  stationary tap shows nothing, matching React's touch
  semantics. Bars get a hovered-column highlight and lines get
  active dots. Tapping a legend entry hides its series (pie
  slices re-normalize over the visible ones, radial rings keep
  their radii, scales never rescale on toggle). The single
  stacked bar has a tooltip (value + percentage) but no legend
  toggle, like React's SegmentedBar. Still missing: Y axis and
  grid (Phase 2), scroll mode and legend forms (Phase 3),
  calibration defaults (Phase 4).
- Charts are fully self-drawn (`CustomPainter` in
  `extra_charts.dart`): fl_chart is removed, so the package's
  only third-party dependency is flutter_markdown_plus.
  Legend formats, box heights, value scales, the z-scaled
  scatter bubbles (now via the pure `computeScatterLayout`)
  and the empty-series radar box are unchanged, and the bar
  chart golden was regenerated (visually identical: same
  heights, rounded tops). Two deliberate changes:
  HorizontalBar category titles are drawn horizontal on the
  left instead of rotated, and a 1- or 2-axis radar draws its
  true geometry (a dot, a line) instead of a padded triangle.
  Known gap, unchanged from the fl_chart version and a React
  parity gap: no hover tooltips (React charts show one by
  default). The SDK floor (Dart ^3.6.2 / Flutter 3.27.4) is
  kept for now although fl_chart no longer requires it.
- Renderer incrementality: `_buildNode` results are memoized by
  node identity, so a rebuild after a streaming push (or a host
  rebuild) reuses the identical Widget for every pure subtree,
  and Flutter's element update short-circuits identical widgets
  without rebuilding below them. A subtree is cached only when
  its build read no form state and ran no custom registry
  builder; theme and streaming changes clear the cache, Query
  results arrive as new nodes and miss naturally, and the cache
  clears at 1000 entries. `Carousel` now uses `PageView.builder`,
  so slide widgets are built on demand instead of all up front.
  Known limit, unchanged from before: the parser re-evaluates
  every statement when form state changes, so a form edit still
  rebuilds the whole tree — memoization's win is streaming
  appends and host rebuilds, not form edits.
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
