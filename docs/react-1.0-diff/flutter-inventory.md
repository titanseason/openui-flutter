# Flutter inventory — openui_flutter component + props (for React 1.0 diff)

- Extracted from git HEAD `9b22cd8` (branch main, local only).
- Component count: **95 total = 86 original GenUI names + 9 extra components**.
- The 9 extra components (added in the fl_chart task): AreaChartCondensed, BarChartCondensed, CalendarHeatmap, FunnelChart, HeatmapChart, LineChartCondensed, MiniBarChart, MiniLineChart, StackedLegend.
- Original 86 names are the GenUI names from @openuidev/react-ui 0.17.0 as recorded in lib/src/library.dart's header comment (layout 13, content 16, data 21, form 19, actions 3, dialogue 4, composite cards 10 — with the 9 extras inserted inside the data section of the file; the split above is by name, not by file position).
- Source of truth for declared props: `lib/src/library.dart` (`openUIStandardLibrary()`; `openUIMvpLibrary()` is a deprecated alias forwarding to it). Renderer behaviour: `lib/src/renderer.dart`, `lib/src/extra_charts.dart`, `lib/src/extra_widgets.dart`.

## How to read this file (semantics that apply to every row)

- **All Lang component props are positional.** The Lang mapper (`_evalComponent` in lib/src/lang.dart) assigns positional arguments to ComponentDef props in declaration order. There is no named-argument syntax for components in this port. The renderer then reads props by name from the ElementNode props map.
- **Requiredness is enforced at parse/map time, not in the renderer.** A missing required prop with no default produces a `missing-required` error and the node is dropped; a null required prop produces `null-required` and the node is dropped; a wrong-typed literal produces `type-mismatch` (falls back to the declared default if one exists, else the prop is skipped when optional or the node is dropped when required). Excess positional args produce `excess-args` but the node is still built with the extra args ignored.
- **The renderer itself is lenient.** `stringOf(name)` defaults to `''`, `nodesOf(name)` defaults to `[]`, `numOf(name)` defaults to `0`. So a 'Required' below means 'the mapper rejects a program that omits it', not 'the renderer throws'.
- **Declared defaults** are the PropDef `defaultValue`s. Only four props in the whole library declare one: TextContent.variant = 'normal', Callout/TextCallout.variant = 'info', Slider.min = 0, Slider.max = 100. Every other fallback in the tables is a renderer-side fallback (stringOf/nodesOf/numOf or explicit code), not a declared default.
- **Prop types** use the PropType enum: string, number, boolean, list, node, nodeList, any, action, actionList. No component in this library uses the `node` or `actionList` types; node children are always `nodeList`, actions are always `action`.

## Findings (declared vs rendered)

### F1 — Declared but NEVER read by the renderer: CodeBlock.language
`CodeBlock` declares `language` (string, optional) but the renderer case reads only `code` and renders plain monospace text. This is the deliberate post-revert state (syntax_highlight was implemented then reverted by user decision; CodeBlock is plain text until a new highlighting decision). Any program passing a language gets it accepted and silently ignored.

### F2 — Declared but only partially used: Image.alt
`Image` declares `alt` (string, optional) but the renderer never uses it as an accessibility label/semantics. Its only use is as the error-placeholder text via `stringOf('alt', '图片加载失败')` — i.e. it shows only when the network image fails, and shows '图片加载失败' when alt is absent.

### F3 — Renderer reads a prop the ComponentDef does NOT declare (dead read): composite-item `src`
The five composite item types share one renderer case that reads `props['src']` for a leading image. Only `VisualItem` declares `src`. For SnippetItem/OverviewItem/ContextItem/CompositeItem a program cannot supply `src` through the Lang mapper (their defs have only `text` + `action`; a third positional arg is an `excess-args` error and is ignored), so the read is dead code for those four types. Harmless, but the shared case implies an API the defs do not offer.

### F4 — Registered but with no dedicated renderer case: 12 parent-read components (by design, not a bug)
Col, Series, Slice, ScatterSeries, Point, SelectItem, ChipItem, FollowUpItem, CheckBoxItem, RadioItem, SwitchItem, OptionCard have no switch case; the renderer default case returns SizedBox.shrink for them standalone (this is documented in the default-case comment). All 12 are read by their parent components (see their sections). No registered component is entirely unhandled: every one of the 95 is either a dedicated case or parent-read.

### F5 — Registered-but-unrendered components: NONE
No component in `openUIStandardLibrary()` lacks both a dedicated case and a parent read path.

### F6 — Renderer-read-but-undeclared props (other than F3): NONE
Every other prop the renderer reads (`tool` on the internal `__QueryError` sentinel, `statementId` on ElementNode) is internal machinery, not a library prop. All other renderer reads match a declared prop on the same component (or on the parent-read child, e.g. Col `label`/`values` read by Table).

### F7 — Renderer-side fallbacks that differ in spirit from the declared contract (notes, not errors)
- Select/Chip/CheckBox/Radio/Switch/OptionCard `value` (optional, any): when absent, the widget falls back to the item's `label` string. So an omitted `value` is not 'no value' at render time, it is the label.
- Input/TextArea `value` (optional, any): used only as the initial field value when the field is unbound or the bind key has no state yet; once bound state exists, state wins.
- Slider `value` (optional, number): fallback chain is form-state number → `value` → `min` → 0.0; `min`/`max` fall back to 0/100 in code, matching the declared defaults.
- CalendarHeatmap `values`: entries whose `date` is not a parseable String or whose `value` is not a num are silently skipped (not an error).
- Series `values`: non-numeric entries become 0 in `seriesValues`; Slice `value` / Point `x`/`y` become 0 via numOf when absent or non-numeric.

## Stack (original 86 GenUI)

_Vertical stack container, the generic root._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| children | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; renders `children` in a Column.

## Card (original 86 GenUI)

_Card container, the chat root._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| children | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; renders `children` in a Card.

## Tabs (original 86 GenUI)

_Tabbed container; pass TabItem nodes as a list._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| items | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case via _TabsWidget; `items` TabItem nodes, labels via stringOf.

## TabItem (original 86 GenUI)

_One tab: label and its content nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| children | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case (renders `children`) and read by _TabsWidget (`label`, `children`).

## Accordion (original 86 GenUI)

_Collapsible panels; pass AccordionItem nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| items | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; renders `items` nodes.

## AccordionItem (original 86 GenUI)

_One collapsible panel: label and its content._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| children | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case (ExpansionTile): `label`, `children`.

## Steps (original 86 GenUI)

_Step list; pass StepsItem nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| items | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; renders `items` with numbered avatars.

## StepsItem (original 86 GenUI)

_One step: label and its content nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| children | nodeList | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case: bold `label`, then `children`.

## Carousel (original 86 GenUI)

_Swipeable pages; pass content nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| children | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; `children` as PageView pages, fixed height 220; empty list renders empty.

## Separator (original 86 GenUI)

_Divider line between blocks._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| _(none)_ | — | — | — | No props; see handling note below. |

Renderer: Dedicated case; no props.

## Modal (original 86 GenUI)

_Dialog-style container; renders as a real AlertDialog._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| title | string | no | — | Positional (order 1); see handling note below. |
| children | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via _ModalWidget: renders nothing inline; AlertDialog titled from `title` (omitted when not a String) with `children` as content and a fixed '关闭' close button.

## SectionBlock (original 86 GenUI)

_Chat grouping block; pass SectionItem nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| title | string | no | — | Positional (order 1); see handling note below. |
| items | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case: optional bold `title`, then `items`.

## SectionItem (original 86 GenUI)

_One grouped item: label and its content nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| children | nodeList | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case: bold `label`, then `children`.

## CardHeader (original 86 GenUI)

_Card title and subtitle._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| title | string | yes | — | Positional (order 1); see handling note below. |
| subtitle | string | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case: `title` (bold 18), `subtitle` rendered only when a String.

## TextContent (original 86 GenUI)

_Body text. variant: small, normal, large, large-heavy._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |
| variant | string | no | 'normal' | Positional (order 2); see handling note below. |

Renderer: Dedicated case; `variant` via stringOf fallback 'normal' (small/normal/large/large-heavy, anything else renders as normal).

## Text (original 86 GenUI)

_Plain inline text._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; `text` via stringOf ('').

## BoldText (original 86 GenUI)

_Bold inline text._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; bold `text`.

## MarkdownRenderer (original 86 GenUI)

_Markdown text rendered by flutter_markdown_plus (full Markdown)._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; `text` rendered by flutter_markdown_plus MarkdownBody.

## Callout (original 86 GenUI)

_Tip/warning block. variant: info, warning, error._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |
| variant | string | no | 'info' | Positional (order 2); see handling note below. |

Renderer: Dedicated case; `variant` via stringOf fallback 'info' (warning→orange, error→red, anything else→blue).

## TextCallout (original 86 GenUI)

_Text tip block. variant: info, warning, error._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |
| variant | string | no | 'info' | Positional (order 2); see handling note below. |

Renderer: Dedicated case via shared _callout helper; `variant` fallback 'info'.

## Image (original 86 GenUI)

_Single image from a network URL._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| src | string | yes | — | Positional (order 1); see handling note below. |
| alt | string | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case; Image.network `src` (height 180, cover); `alt` is NOT used as an accessibility label — it is only the error-placeholder text, via stringOf fallback '图片加载失败'.

## ImageBlock (original 86 GenUI)

_Image with an optional caption._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| src | string | yes | — | Positional (order 1); see handling note below. |
| caption | string | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case; `src` (height 180), `caption` rendered only when a String.

## ImageGallery (original 86 GenUI)

_Horizontal gallery; images is a list of URLs._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| images | list | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; `images` via _strings (non-list → []).

## ImageText (original 86 GenUI)

_Small image beside text._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| src | string | yes | — | Positional (order 1); see handling note below. |
| text | string | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case; `src` 80x80 + `text`.

## ImageTextLarge (original 86 GenUI)

_Large image above text._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| src | string | yes | — | Positional (order 1); see handling note below. |
| text | string | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case; `src` height 200 + `text`.

## IconText (original 86 GenUI)

_Icon plus text; icon is a name like "search"._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| icon | string | yes | — | Positional (order 1); see handling note below. |
| text | string | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case; `icon` via iconByName, `text`.

## CodeBlock (original 86 GenUI)

_Code block; language is a hint string._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| code | string | yes | — | Positional (order 1); see handling note below. |
| language | string | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case; renders ONLY `code` as monospace text on grey. `language` is never read (see Finding F1).

## InlineHeader (original 86 GenUI)

_Inline heading text._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; bold `text` (16).

## Icon (original 86 GenUI)

_Icon by name like "search"; also used as Tag.icon._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| name | string | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; `name` via iconByName.

## Table (original 86 GenUI)

_Columnar table; pass Col nodes as a list._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| columns | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; `columns` Col nodes. Failed-Query column surfaces error text; loading-Query column renders TableSkeleton; Col `values` fallback [], `label` via stringOf.

## Col (original 86 GenUI)

_One table column: label and a list of cell values._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| values | list | yes | — | Positional (order 2); see handling note below. |

Renderer: No dedicated switch case; read by Table/EditableTable parents: `label` via stringOf ('' if missing), `values` via `props['values'] as List? ?? []`. Renders as empty (SizedBox.shrink) standalone (renderer default case).

## EditableTable (original 86 GenUI)

_Table whose cells are editable text fields. bind: when true, each cell writes to form state under "<statementId>:<columnLabel>:<row>"._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| columns | nodeList | yes | — | Positional (order 1); see handling note below. |
| bind | boolean | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case; `columns` Col nodes; `bind` read as `props['bind'] == true` (strict bool). Bound cells use statementId-qualified form keys.

## BarChart (original 86 GenUI)

_Bar chart: categories plus Series nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| categories | list | yes | — | Positional (order 1); see handling note below. |
| series | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via _ChartWidget (fl_chart bar); `categories` via _strings, `series` Series nodes, theme chartPalette.

## LineChart (original 86 GenUI)

_Line chart: categories plus Series nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| categories | list | yes | — | Positional (order 1); see handling note below. |
| series | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via _ChartWidget (fl_chart line).

## AreaChart (original 86 GenUI)

_Area chart: categories plus Series nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| categories | list | yes | — | Positional (order 1); see handling note below. |
| series | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via _ChartWidget (fl_chart line, area: true).

## RadarChart (original 86 GenUI)

_Radar chart: axes plus Series nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| categories | list | yes | — | Positional (order 1); see handling note below. |
| series | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via RadarChartWidget (fl_chart radar); <3 categories padded with zero entries; empty series returns a bordered empty box (fix for fl_chart non-empty assertion).

## HorizontalBarChart (original 86 GenUI)

_Horizontal bar chart: categories plus Series._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| categories | list | yes | — | Positional (order 1); see handling note below. |
| series | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via _ChartWidget (fl_chart bar, horizontal: true).

## Series (original 86 GenUI)

_One chart series: label and numeric values._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| values | list | yes | — | Positional (order 2); see handling note below. |

Renderer: No dedicated switch case; read by chart widgets: `label` via stringOf (''), `values` via `seriesValues` (non-numeric entries become 0). Empty standalone.

## PieChart (original 86 GenUI)

_Pie chart; pass Slice nodes as a list._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| slices | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case via _PieWidget (fl_chart pie); slices label/value.

## RadialChart (original 86 GenUI)

_Radial chart; pass Slice nodes as a list._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| slices | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case via RadialChartWidget (fl_chart gauge rings).

## SingleStackedBarChart (original 86 GenUI)

_One segmented bar; pass Slice nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| slices | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case via SingleStackedBarWidget (fl_chart stacked rod); legend shows `label (pct%)`.

## Slice (original 86 GenUI)

_One pie/radial/stacked slice: label and numeric value._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| value | number | yes | — | Positional (order 2); see handling note below. |

Renderer: No dedicated switch case; read by Pie/Radial/Stacked/Funnel widgets: `label` via stringOf (''), `value` via numOf (0). Empty standalone.

## ScatterChart (original 86 GenUI)

_Scatter chart; pass ScatterSeries nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| series | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case via ScatterChartWidget (fl_chart scatter).

## ScatterSeries (original 86 GenUI)

_One scatter series: label and Point nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| points | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: No dedicated switch case; read by FlScatterChartWidget via `nodesOf('points')`; `label` via stringOf (''). Empty standalone.

## Point (original 86 GenUI)

_One scatter point: x and y numbers._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| x | number | yes | — | Positional (order 1); see handling note below. |
| y | number | yes | — | Positional (order 2); see handling note below. |

Renderer: No dedicated switch case; read by FlScatterChartWidget: `x`/`y` via numOf (0). Empty standalone.

## HeatmapChart (extra (fl_chart task))

_Heatmap: categories plus Series nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| categories | list | yes | — | Positional (order 1); see handling note below. |
| series | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via HeatmapChartWidget (self-drawn); `categories` + Series nodes, first palette colour at opacity by value/max.

## FunnelChart (extra (fl_chart task))

_Funnel; pass Slice nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| slices | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case via FunnelChartWidget (self-drawn); Slice nodes, trapezoids narrow by value.

## CalendarHeatmap (extra (fl_chart task))

_Calendar heatmap; values are {date, value} maps._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| values | list | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case via CalendarHeatmapWidget (self-drawn); `values` list of maps — entries are used only when `date` is a String parseable by DateTime.tryParse and `value` is a num; anything else is skipped; empty map renders empty.

## MiniBarChart (extra (fl_chart task))

_Mini bar chart; values are numbers._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| values | list | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case via MiniBarChartWidget (fl_chart bar, height 48, no axes/legend); `values` via _numbers (non-numeric → 0).

## MiniLineChart (extra (fl_chart task))

_Mini line chart; values are numbers._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| values | list | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case via MiniLineChartWidget (fl_chart line, height 48, no axes/legend, no dots).

## StackedLegend (extra (fl_chart task))

_Legend swatches; pass Series nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| series | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case via StackedLegendWidget; Series nodes, swatches + labels only, no chart area.

## BarChartCondensed (extra (fl_chart task))

_Condensed bar chart: categories plus Series nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| categories | list | yes | — | Positional (order 1); see handling note below. |
| series | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via FlBarChartWidget (height 120, showLegend: false).

## LineChartCondensed (extra (fl_chart task))

_Condensed line chart: categories plus Series nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| categories | list | yes | — | Positional (order 1); see handling note below. |
| series | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via FlLineChartWidget (height 120, showLegend: false).

## AreaChartCondensed (extra (fl_chart task))

_Condensed area chart: categories plus Series nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| categories | list | yes | — | Positional (order 1); see handling note below. |
| series | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via FlLineChartWidget (height 120, showLegend: false, area: true).

## TagBlock (original 86 GenUI)

_Tag list; pass Tag nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| items | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; renders `items` Tag nodes in a Wrap.

## Tag (original 86 GenUI)

_One tag chip; icon is an optional icon name._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| icon | string | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case; Chip with `label`, avatar icon only when `icon` is a String.

## EntityList (original 86 GenUI)

_Entity list; items is a list of strings._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| items | list | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; `items` via _strings, one ListTile each.

## MetricIndicatorInline (original 86 GenUI)

_Inline metric: label, value, optional change._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| value | any | yes | — | Positional (order 2); see handling note below. |
| change | string | no | — | Positional (order 3); see handling note below. |

Renderer: Dedicated case; `label`, `value` (any, stringified), `change` rendered only when a String (red if it starts with '-').

## MetricIndicatorWithStrikethrough (original 86 GenUI)

_Metric with struck-through old value._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| value | any | yes | — | Positional (order 2); see handling note below. |
| oldValue | any | no | — | Positional (order 3); see handling note below. |

Renderer: Dedicated case; `label`, `value`, `oldValue` struck through when non-null.

## Form (original 86 GenUI)

_Form container; children are inputs and buttons._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| children | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; renders `children` in a Column.

## FormControl (original 86 GenUI)

_Field wrapper: label, children, optional hint._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| children | nodeList | yes | — | Positional (order 2); see handling note below. |
| hint | string | no | — | Positional (order 3); see handling note below. |

Renderer: Dedicated case: bold `label`, `children`, `hint` only when a String.

## Label (original 86 GenUI)

_Field label text._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; bold `text`.

## Input (original 86 GenUI)

_Single-line text input. bind: state key to write to._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| bind | string | no | — | Positional (order 2); see handling note below. |
| value | any | no | — | Positional (order 3); see handling note below. |
| placeholder | string | no | — | Positional (order 4); see handling note below. |

Renderer: Dedicated case; `label`; `bind` (String only, else unbound); initial value = form state when bound and present, else `value` stringified, else ''; `placeholder` as hint only when a String; disabled while streaming.

## TextArea (original 86 GenUI)

_Multi-line text input. bind: state key to write to._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| bind | string | no | — | Positional (order 2); see handling note below. |
| value | any | no | — | Positional (order 3); see handling note below. |
| placeholder | string | no | — | Positional (order 4); see handling note below. |

Renderer: Dedicated case; same as Input, maxLines 4.

## Select (original 86 GenUI)

_Dropdown; pass SelectItem nodes as a list._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| options | nodeList | yes | — | Positional (order 1); see handling note below. |
| bind | string | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via _SelectWidget; `options` SelectItem nodes, `bind` (String only); current value falls back to first option's value/label.

## SelectItem (original 86 GenUI)

_One dropdown option._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| value | any | no | — | Positional (order 2); see handling note below. |

Renderer: No dedicated switch case; read by _SelectWidget: `label` via stringOf (''), `value` via `props['value'] ?? label`. Empty standalone.

## DatePicker (original 86 GenUI)

_Date picker; writes an ISO date to bind._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| bind | string | no | — | Positional (order 2); see handling note below. |
| value | string | no | — | Positional (order 3); see handling note below. |

Renderer: Dedicated case via DatePickerField; `label`; `bind` (String only); value = form state when bound and present, else `value` when a String, else null.

## Slider (original 86 GenUI)

_Slider; writes a number to bind._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| bind | string | no | — | Positional (order 2); see handling note below. |
| value | number | no | — | Positional (order 3); see handling note below. |
| min | number | no | 0 | Positional (order 4); see handling note below. |
| max | number | no | 100 | Positional (order 5); see handling note below. |

Renderer: Dedicated case via SliderField; `label`; `bind` (String only); value chain: form state num → `value` num → `min` num → 0.0; `min` fallback 0, `max` fallback 100 (def defaults 0/100 match).

## CheckBoxGroup (original 86 GenUI)

_Multi-select group; pass CheckBoxItem nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| items | nodeList | yes | — | Positional (order 1); see handling note below. |
| bind | string | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via MultiSelectGroupWidget; `items` CheckBoxItem nodes, `bind` (String only).

## CheckBoxItem (original 86 GenUI)

_One checkbox option._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| value | any | no | — | Positional (order 2); see handling note below. |

Renderer: No dedicated switch case; read by MultiSelectGroupWidget: `label` via stringOf (''), `value` via `props['value'] ?? label`. Empty standalone.

## RadioGroup (original 86 GenUI)

_Single-select group; pass RadioItem nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| items | nodeList | yes | — | Positional (order 1); see handling note below. |
| bind | string | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via SingleSelectGroupWidget; `items` RadioItem nodes, `bind` (String only).

## RadioItem (original 86 GenUI)

_One radio option._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| value | any | no | — | Positional (order 2); see handling note below. |

Renderer: No dedicated switch case; read by SingleSelectGroupWidget: `label` via stringOf (''), `value` via `props['value'] ?? label`. Empty standalone.

## SwitchGroup (original 86 GenUI)

_Switch group; pass SwitchItem nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| items | nodeList | yes | — | Positional (order 1); see handling note below. |
| bind | string | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via SwitchGroupWidget; `items` SwitchItem nodes, `bind` (String only).

## SwitchItem (original 86 GenUI)

_One switch option._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| value | any | no | — | Positional (order 2); see handling note below. |

Renderer: No dedicated switch case; read by SwitchGroupWidget: `label` via stringOf (''), `value` via `props['value'] ?? label`. Empty standalone.

## Chips (original 86 GenUI)

_Quick-choice chips; pass ChipItem nodes as a list._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| items | nodeList | yes | — | Positional (order 1); see handling note below. |
| bind | string | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via _ChipsWidget; `items` ChipItem nodes, `bind` (String only).

## ChipItem (original 86 GenUI)

_One chip option._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| value | any | no | — | Positional (order 2); see handling note below. |

Renderer: No dedicated switch case; read by _ChipsWidget: `label` via stringOf (''), `value` via `props['value'] ?? label`. Empty standalone.

## OptionCards (original 86 GenUI)

_Selectable cards; pass OptionCard nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| items | nodeList | yes | — | Positional (order 1); see handling note below. |
| bind | string | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case via SingleSelectGroupWidget (asCards: true); `items` OptionCard nodes, `bind` (String only).

## OptionCard (original 86 GenUI)

_One selectable card: label, optional description._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| value | any | no | — | Positional (order 2); see handling note below. |
| description | string | no | — | Positional (order 3); see handling note below. |

Renderer: No dedicated switch case; read by SingleSelectGroupWidget (asCards): `label` via stringOf (''), `value` via `props['value'] ?? label`, `description` shown as subtitle when a String. Empty standalone.

## Button (original 86 GenUI)

_Button with an optional action._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| label | string | yes | — | Positional (order 1); see handling note below. |
| action | action | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case; `label`; `action` dispatched (disabled while streaming).

## Buttons (original 86 GenUI)

_Button group; pass Button nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| children | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; renders `children` Button nodes in a Wrap.

## IconButton (original 86 GenUI)

_Icon button; icon is a name like "search"._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| icon | string | yes | — | Positional (order 1); see handling note below. |
| action | action | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case; `icon` via iconByName, `action` dispatched (disabled while streaming).

## FollowUpBlock (original 86 GenUI)

_Follow-up suggestions; pass FollowUpItem nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| items | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; `items` FollowUpItem nodes rendered as OutlinedButtons; tap dispatches ToAssistant with the item text.

## FollowUpItem (original 86 GenUI)

_One follow-up: tapping sends it as the next question._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |

Renderer: No dedicated switch case; read by FollowUpBlock: `text` via stringOf (''); tap synthesises a ToAssistant action. Empty standalone.

## ListBlock (original 86 GenUI)

_List block; pass ListItem nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| items | nodeList | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; renders `items` ListItem nodes.

## ListItem (original 86 GenUI)

_One list item text._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |

Renderer: Dedicated case; ListTile with '•' leading, `text`.

## SnippetBlock (original 86 GenUI)

_Snippet card block; pass SnippetItem nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| title | string | no | — | Positional (order 1); see handling note below. |
| items | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case (shared composite-card case); optional bold `title`, then `items`.

## SnippetItem (original 86 GenUI)

_One snippet item: text and optional action._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |
| action | action | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case (shared composite-item case); `text`, optional leading image from `src` (see Finding F3), tap dispatches `action` when non-null.

## OverviewBlock (original 86 GenUI)

_Overview card block; pass OverviewItem nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| title | string | no | — | Positional (order 1); see handling note below. |
| items | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case (shared composite-card case); optional bold `title`, then `items`.

## OverviewItem (original 86 GenUI)

_One overview item: text and optional action._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |
| action | action | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case (shared composite-item case); `text`, optional leading image from `src` (see Finding F3), tap dispatches `action` when non-null.

## ContextBlock (original 86 GenUI)

_Context card block; pass ContextItem nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| title | string | no | — | Positional (order 1); see handling note below. |
| items | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case (shared composite-card case); optional bold `title`, then `items`.

## ContextItem (original 86 GenUI)

_One context item: text and optional action._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |
| action | action | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case (shared composite-item case); `text`, optional leading image from `src` (see Finding F3), tap dispatches `action` when non-null.

## CompositeBlock (original 86 GenUI)

_Composite card block; pass CompositeItem nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| title | string | no | — | Positional (order 1); see handling note below. |
| items | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case (shared composite-card case); optional bold `title`, then `items`.

## CompositeItem (original 86 GenUI)

_One composite item: text and optional action._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |
| action | action | no | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case (shared composite-item case); `text`, optional leading image from `src` (see Finding F3), tap dispatches `action` when non-null.

## VisualBlock (original 86 GenUI)

_Visual card block; pass VisualItem nodes._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| title | string | no | — | Positional (order 1); see handling note below. |
| items | nodeList | yes | — | Positional (order 2); see handling note below. |

Renderer: Dedicated case (shared composite-card case); optional bold `title`, then `items`.

## VisualItem (original 86 GenUI)

_One visual item: text, optional image src and action._

| Prop | Type | Required | Declared default | Renderer handling |
|---|---|---|---|---|
| text | string | yes | — | Positional (order 1); see handling note below. |
| src | string | no | — | Positional (order 2); see handling note below. |
| action | action | no | — | Positional (order 3); see handling note below. |

Renderer: Dedicated case (shared composite-item case); `text`, leading image from `src` when a String, tap dispatches `action` when non-null.

## Host-only primitives (NOT GenUI components — no ComponentDef, not invocable from Lang)

`lib/src/primitives.dart` exports plain Flutter widgets a host uses directly; they are not registered in `openUIStandardLibrary()` and cannot be produced by a Lang program. The renderer's internal `_Skeleton` (3 grey300 bars, no parameters) is a separate widget from `Skeleton` below.

| Widget | Constructor props (all named, Dart-side) | Notes |
|---|---|---|
| Skeleton | `count: int = 3`, `color: Color?` (fallback grey300) | One 16px bar per count, vertical Column. |
| TableSkeleton | `columns: int = 3`, `rows: int = 4`, `color: Color?` (fallback grey300) | Grid of placeholder cells; also rendered by the Table case when a column is a loading Query. |
| Citation | `index: int` (required), `title: String` (required), `url: String?`, `onTap: VoidCallback?` | Renders `[n]` Chip; `title` is the tooltip; tap calls `onTap` when supplied, else no-op. `url` is carried but never navigated by the widget itself. |
| Sources | `items: List<SourceItem>` (required) | SourceItem = `({String title, String? url, String? faviconUrl})`. One row per item; favicon via Image.network when present (error → empty box); row tap is a no-op (no link handler exists). `url` is carried but never opened. |

## AgentInterface (no GenUI components)

`lib/src/agent/` (agent_interface.dart, agent_slots.dart, agent_storage.dart, agent_tools.dart) registers no components: it contains no ComponentDef, no registry builder, and no library extension. AgentInterface is a shell widget that renders Lang programs through OpenUIRenderer; it contributes no names to the 95-component inventory above.

