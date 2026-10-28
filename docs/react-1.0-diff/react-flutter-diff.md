# React 0.18.1 vs Flutter port — full diff (schema-level, definitive)

- **Fetch date:** 2026-10-28 (source read; earlier web-only round same day).
- **React side:** Lang 1.0 spec + `@openuidev/react-ui` 0.18.1, repo
  `thesysdev/openui`, HEAD `f08a660535e55b5b2a24a0eb68568edaf9e4fe4b`.
  Basis document: `react-source-props.md` in this directory — every React
  prop below is read from `packages/react-ui/src/genui-lib` source
  (Zod schemas + `defineComponent` names), not from docs examples.
- **Flutter side:** `openui_flutter` 1.0.0, local git `main` HEAD `9b22cd8`,
  95 components. Basis document: `flutter-inventory.md` in this directory.
- **Step 1 result (superseded):** the earlier web-only round (6 searches +
  2 page fetches) could not reach the genui-lib source and left 73
  components "unverifiable". That caveat is now REPLACED: the source was
  read directly from a local sparse checkout of genui-lib, and §d gives a
  schema-level verdict for every component. Nothing in this report invents
  a React prop; the few things the checkout could not establish are
  listed per item in §4 of `react-source-props.md` and in "Remaining
  caveats" below.

## Headline counts

| Measure | Count |
| --- | --- |
| React registered GenUI names (source, union of both libraries) | **86** |
| General library (`openuiLibrary`, root `Stack`) | 82 |
| Chat library (`openuiChatLibrary`, root `Card`) | 84 |
| Flutter components total | 95 |
| (a) React GenUI names missing from Flutter | **11** (1 casing + 10 Card-suffix names) |
| (b) Flutter-only components | **20** (11 renamed variants of React names + 9 extras) |
| (c) Confirmed name mismatches | **11** (same 11 as (a); no unresolved alias groups remain) |
| (d) Schema-verified exact props parity | **7 of 86** |
| (d) Schema-verified positional parity with a name-only difference | **3 of 86** |
| (d) Partially verified (Icon: name confirmed, full schema not in checkout) | 1 |
| (d) With props gaps / shape differences | **75 of 86** |
| (d) Props unverifiable from the checkout | **0** (except Icon's `category` detail) |
| (d) Host primitives with verified default divergence (not GenUI) | 2 (`Skeleton`, `TableSkeleton`) |
| (e) Flutter-internal notes carried over | F1–F7 + 12 parent-read components |

Reading rule: verdicts compare **schema declaration order** (React) with
**declaration order** (Flutter), because Lang calls in the repo's own
notes are positional in schema order (`Tag(t.priority, null, "sm")` =
text/icon/size, `Col("Sales", sales, "number")` = label/data/type,
`Callout("success", "Saved", "Done.", $showSuccess)` =
variant/title/description/visible, `Form("edit", Buttons(...),
[fields...])` = name/buttons/fields). Verdict codes: **P** = exact
parity (same slots, order, requiredness, defaults); **N** = same slots
and order, only the prop NAME differs (a positional program still
works); **G** = gap (React props Flutter lacks, or a requiredness
mismatch); **S** = shape difference (different prop structure, types,
or semantics — a positional program does NOT port as written);
**O** = same props, different ORDER; **X** = Flutter has a prop React
lacks (listed separately). A row can carry several codes.

## (f) Version-baseline correction — read first

**"react-ui 1.0" is wrong.** The "1.0" belongs to the language, not the
component package:

| Piece | Version |
| --- | --- |
| OpenUI Lang (spec, updated 2026-10-26) | 1.0 |
| `@openuidev/lang-core` / `@openuidev/react-lang` | 1.0.1 |
| `@openuidev/react-ui` (npm `latest`, jsDelivr, package README) | **0.18.1** |

The 0.18 README itself says "react-ui 0.18 renders OpenUI Lang 1.0".
Any statement of the form "react-ui 1.0" should be corrected to
"react-ui 0.18.1 rendering Lang 1.0".

**0.17.0 → 0.18.1 component delta: the count was right, the identifiers
were wrong.** The registered 0.18.1 set is 86 names — coincidentally the
same count as the carried-over 0.17 baseline — but 11 of the baseline's
identifiers do not exist in source (see §a/§c). Whether those 11 are
0.18 renames or were already the 0.17 GenUI names cannot be established
from this checkout (no 0.17 source in it); what IS established is that
the earlier report's "0 missing" verdict falls, because it was measured
against the wrong identifiers. What is established for 0.18 as runtime
(not component) change: lone action form, custom functions
(`defineFunction`) and custom actions (`defineAction`),
`library.extend` (add / override / remove), stored-message format
(`]]>openui:` markers), new error codes `unknown-function` and
`no-root`, `action()` replacing `tagSchemaId(z.any(),
"ActionExpression")`, React 19 + react-lang 1.x peer deps.

## (a) In React 0.18.1 but MISSING from Flutter — 11

Every missing name is a name Flutter spells differently, not a concept
Flutter lacks. A Lang program written for React using any of these 11
identifiers fails in Flutter with `unknown-component`, and vice versa.

| Name | Library (React) | Flutter's (non-matching) spelling |
| --- | --- | --- |
| `MarkDownRenderer` | both | `MarkdownRenderer` (capital D lost) |
| `SnippetCardBlock` / `SnippetCardItem` | both | `SnippetBlock` / `SnippetItem` |
| `OverviewCardBlock` / `OverviewCardItem` | both | `OverviewBlock` / `OverviewItem` |
| `ContextCardBlock` / `ContextCardItem` | both | `ContextBlock` / `ContextItem` |
| `CompositeCardBlock` / `CompositeCardItem` | both | `CompositeBlock` / `CompositeItem` |
| `VisualCardBlock` / `VisualCardItem` | both | `VisualBlock` / `VisualItem` |

Not missing (corrections to the earlier report): `SegmentedBar` is not a
GenUI name at all (zero hits in the checkout); `SingleStackedBar` is
only the underlying chart widget imported from outside genui-lib, not a
Lang-invocable name. `SourceFaviconImage`, `ToolCall`, `ToolResult`,
`AgentInterface` are not GenUI registrations either. `BarChart` /
`LineChart` / `AreaChart` ARE registered — via the `*Condensed.ts`
files, which register the short names (see §b).

### Library-membership note (not a missing component, but a parity gap)

React ships **two** libraries: `openuiLibrary` (root `Stack`, full suite
except FollowUp/Section) and `openuiChatLibrary` (root `Card`,
chat-optimized; excludes `Stack` and `Modal`, includes `FollowUpBlock`,
`FollowUpItem`, `SectionBlock`, `SectionItem`). Flutter ships **one**
merged library, `openUIStandardLibrary()`, containing all 95 names. So a
Flutter program may combine `Stack` with `FollowUpBlock` in one tree,
which neither React library accepts, and Flutter has no chat-`Card`
variant (no `sources` prop) and no general-`Card` variant (no `variant`
or flex props). No component is missing on membership grounds, but the
library-membership boundary is not preserved.

## (b) In Flutter but NOT in React's GenUI library — 20

**11 renamed variants** (same concept, wrong identifier — see §a):
`MarkdownRenderer`, `SnippetBlock`, `SnippetItem`, `OverviewBlock`,
`OverviewItem`, `ContextBlock`, `ContextItem`, `CompositeBlock`,
`CompositeItem`, `VisualBlock`, `VisualItem`.

**9 extras** (Flutter-only as Lang-invocable components):

| Flutter component | React status (source) | Flutter props |
| --- | --- | --- |
| `BarChartCondensed` | NOT a GenUI name — `BarChartCondensed.ts` registers `BarChart` | categories\*, series\* |
| `LineChartCondensed` | NOT a GenUI name — `LineChartCondensed.ts` registers `LineChart` | categories\*, series\* |
| `AreaChartCondensed` | NOT a GenUI name — `AreaChartCondensed.ts` registers `AreaChart` | categories\*, series\* |
| `HeatmapChart` | No GenUI registration (zero hits in checkout) | categories\*, series\* |
| `FunnelChart` | No GenUI registration (zero hits in checkout) | slices\* |
| `CalendarHeatmap` | No GenUI registration (zero hits in checkout) | values\* |
| `MiniBarChart` | No GenUI registration (zero hits in checkout) | values\* |
| `MiniLineChart` | No GenUI registration (zero hits in checkout) | values\* |
| `StackedLegend` | No GenUI registration (zero hits in checkout) | series\* |

`\*` = required in Flutter. Whether the last six exist as non-GenUI UI
primitives under `packages/react-ui/src/components` could NOT be
checked from the sparse checkout (that directory is outside it) — the
claim here is only about GenUI registration, not about their existence
as widgets.

## (c) Name mismatches — all resolved, none left open

| Question | Verdict | Evidence (source) |
| --- | --- | --- |
| `MarkDownRenderer` vs `MarkdownRenderer` | **Confirmed mismatch** | `defineComponent({ name: "MarkDownRenderer" })`, schema prop `textMarkdown`. Flutter registers `MarkdownRenderer`. |
| `SnippetBlock` vs `SnippetCardBlock` (+ 4 sibling block/item pairs) | **Confirmed mismatch (10 names)** | Registered names keep the `Card` suffix in all five block schemas and all five item `defineComponent` calls. The earlier "GenUI-facing names govern (short)" claim is contradicted by source. |
| `SingleStackedBarChart` vs `SingleStackedBar` / `SegmentedBar` | **Resolved: `SingleStackedBarChart` is the registered name** | `Charts/SingleStackedBarChart.ts` registers `SingleStackedBarChart`; `SingleStackedBar` is only the imported widget; `SegmentedBar` has zero hits. Flutter's name matches; its SHAPE does not (see §d). |
| Are the 9 extras in React's GenUI library? | **Resolved: no** | No registration for any of the 9 names in either library file or any schema (see §b). |
| Chat-variant components | **Resolved** | Chat `Card`/`Tabs`/`TabItem`/`Accordion`/`AccordionItem`/`Carousel`/`SectionBlock`/`SectionItem` are separate definitions under the same names with wider content unions; general `Tabs`/`Accordion`/`Carousel` use the base union. Flutter's single variants match neither (see §d). |

## (d) Props comparison — schema level, all 86 React names

Flutter props are from `flutter-inventory.md` (HEAD `9b22cd8`).
"React" below is the schema in `react-source-props.md` §2, in
declaration order. For the 11 renamed components the Flutter counterpart
is the short/casing variant.

| Component | React props (schema order) | Flutter props | Verdict |
| --- | --- | --- | --- |
| Stack (general only) | children\*, direction?, gap?, align?, justify?, wrap? | children\* | G (5 flex props missing — D1 settled) |
| Card (general) | children\*, variant?, + flex props | children\* | G (variant + 5 flex missing) |
| Card (chat) | children\*, sources? | children\* | G (sources missing; no chat variant at all) |
| Tabs | items\* | items\* | P |
| TabItem | value\*, trigger\*, content\* | label\*, children\* | S (D2 settled) |
| Accordion | items\* | items\* | P |
| AccordionItem | value\*, trigger\*, content\* | label\*, children\* | S (D2 settled) |
| Steps | items\* | items\* | P |
| StepsItem | title\*, details\* | label\*, children? | S (strings vs label+nodes) |
| Carousel | children\* (array of slide arrays), variant? | children\* (flat node list) | S + G (nested slides; variant missing) |
| Separator | orientation?, decorative? | — | G (2 optional missing) |
| Modal (general only) | title\*, open?, children\*, size? | title?, children\* | G (title required→optional; open/size missing) |
| SectionBlock (chat only) | sections\*, isFoldable? | title?, items\* | S + X (title extra; sections→items; isFoldable missing) |
| SectionItem (chat only) | value\*, trigger\*, content\* | label\*, children? | S |
| CardHeader | title?, subtitle? | title\*, subtitle | G (title required in Flutter, optional in React) |
| TextContent | text\*, size? (small/default/large/small-heavy/large-heavy) | text\*, variant='normal' | G (size→variant name; value set differs: no 'normal' in React; small-heavy/large-heavy/default missing) |
| Text | variant='text', value\*, subtext?, subtextVariant='text', size='sm' | text\* | S (core prop is `value`, not `text`; variant/subtext/size missing; see positional caveat) |
| BoldText | variant='text', value\*, subtext?, subtextVariant='text', size='sm' | text\* | S (same as Text) |
| MarkDownRenderer | textMarkdown\*, variant? (clear/card/sunk) | text\* (as `MarkdownRenderer`) | G + name (textMarkdown→text; variant missing; casing §c) |
| Callout | variant\*, title\*, description\*, visible? | text\*, variant='info' | S (title+description vs single text; variant required vs defaulted; visible missing) |
| TextCallout | variant?, title?, description? | text\*, variant='info' | S (all-optional triple vs required text) |
| Image | alt\*, src? | src\*, alt | G + O (requiredness swapped: alt required/src optional in React; order swapped) |
| ImageBlock | src\*, alt? | src\*, caption? | G + X (alt missing; caption extra) |
| ImageGallery | images\* (array of {src\*, alt?, details?}) | images\* (list of strings) | S (element type: objects vs strings) |
| ImageText | src\*, alt?, title\*, subtitle?, bold=false, layout='horizontal', imageSize? | src\*, text\* | S (title/subtitle vs single text; alt/bold/layout/imageSize missing) |
| ImageTextLarge | src\*, alt?, title\*, subtitle?, bold=false | src\*, text\* | S (same pattern) |
| IconText | icon\* (Icon ref), iconVariant='neutral', iconSize='m', title\*, subtitle?, bold=false, layout='horizontal' | icon\* (string name), text\* | S (icon is an Icon ref, not a string; title/subtitle vs text; 4 props missing) |
| CodeBlock | language\*, codeString\* | code\*, language? | O + G (order swapped; language required→optional; codeString→code) |
| InlineHeader | heading\*, description? | text\* | S (heading+description vs text) |
| Icon | name\*, category? | name\* | Partial (name matches; `category` exact schema not in checkout) |
| Table | columns\* (Col refs) | columns\* | P |
| Col | label\*, data\* (any), type? (string/number/action) | label\*, values\* | G + name (data→values; type missing — D3 settled) |
| EditableTable | name='', columns=[] ({type, key, header, width?, options?}), data=[] ({id, values}) — all defaulted | columns\* (Col nodes), bind? | S (name+column-defs+data-rows vs Col nodes+bind) |
| BarChart | labels\*, series\*, variant? (grouped/stacked), xLabel?, yLabel?, height? | categories\*, series\* | G + name (labels→categories; variant/xLabel/yLabel/height missing) |
| LineChart | labels\*, series\*, variant? (linear/natural/step), xLabel?, yLabel?, height? | categories\*, series\* | G + name |
| AreaChart | labels\*, series\*, variant? (linear/natural/step), xLabel?, yLabel?, height? | categories\*, series\* | G + name |
| RadarChart | labels\*, series\* | categories\*, series\* | N (labels→categories only) |
| HorizontalBarChart | labels\*, series\*, variant? (grouped/stacked), xLabel?, yLabel? | categories\*, series\* | G + name |
| Series | category\*, values\* (number[]) | label\*, values\* | N (category→label only) |
| PieChart | labels\* (string[]), values\* (number[]), variant? (pie/donut), appearance? (circular/semiCircular) | slices\* (Slice nodes) | S (labels+values arrays vs Slice nodes; variant/appearance missing) |
| RadialChart | labels\*, values\* | slices\* | S |
| SingleStackedBarChart | labels\*, values\* | slices\* | S (name matches; shape does not) |
| Slice | category\*, value\* | label\*, value\* | N (category→label only) |
| ScatterChart | datasets\* (ScatterSeriesSchema[]), xLabel?, yLabel? | series\* (ScatterSeries nodes) | S + name (datasets→series; schema objects vs component nodes; xLabel/yLabel missing) |
| ScatterSeries | name\*, points\* (PointSchema[]) | label\*, points\* (Point nodes) | S + name (name→label; schema objects vs component nodes) |
| Point | x\*, y\*, z? | x\*, y\* | G (z missing) |
| TagBlock | tags\* (string[]), size? (sm/md/lg) | items\* (Tag nodes) | S (strings vs Tag nodes; size missing) |
| Tag | text\*, icon? (Icon ref), size? (sm/md/lg), variant? (neutral/info/success/warning/danger) | label\*, icon? (string) | G + name + type (text→label; icon ref vs string; size/variant missing — D4 settled) |
| EntityList | rows\* ({left\*, right\*, rightVariant='text'}), size='default', header?, footer? | items\* (string list) | S (row objects vs strings; size/header/footer missing) |
| MetricIndicatorInline | value\* (string), subtext?, trend? ({direction, value}) | label\*, value\* (any), change? | S + X (no label in React; subtext/trend vs change) |
| MetricIndicatorWithStrikethrough | value\*, subtext?, previousValue?, trend? | label\*, value\*, oldValue? | G + name + X (previousValue→oldValue; label extra; subtext/trend missing) |
| Form | name\*, buttons\* (Buttons ref), fields=[] (FormControl refs) | children\* | S (D5 settled) |
| FormControl | label\*, input\* (union of 9 field refs; NO SwitchGroup), hint? | label\*, children\*, hint? | S (single field ref vs any children; SwitchGroup excluded in React) |
| Label | text\* | text\* | P |
| Input | name\*, placeholder?, type? (text/email/password/number/url), rules?, value? (reactive string) | label\*, bind?, value?, placeholder? | S (name-based vs label+bind; type/rules missing — D2 settled) |
| TextArea | name\*, placeholder?, rows?, rules?, value? (reactive string) | label\*, bind?, value?, placeholder? | S (rows/rules missing; name vs label+bind) |
| Select | name\*, items\* (SelectItem refs), placeholder?, rules?, value? (reactive string), size? (small/medium/large) | options\*, bind? | S (name/items vs options/bind; placeholder/rules/value/size missing) |
| SelectItem | value\*, label\* | label\*, value? | O + G (order swapped; value required→optional) |
| DatePicker | name\*, mode? (single/range), rules?, value? (reactive unknown) | label\*, bind?, value? (string) | S (mode/rules missing; name vs label+bind) |
| Slider | name\*, variant\* (continuous/discrete), min\*, max\*, step?, defaultValue? (number[]), label?, rules?, value? (reactive number[]) | label\*, bind?, value? (number), min=0, max=100 | S (value scalar vs array; variant required missing; min/max required vs defaulted; name vs bind) |
| CheckBoxGroup | name\*, items\*, rules?, value? (reactive record<string,boolean>) | items\*, bind? | S (name vs bind; rules missing) |
| CheckBoxItem | label\*, description\*, name\*, defaultChecked? | label\*, value? | S (description+name vs value; defaultChecked missing) |
| RadioGroup | name\*, items\*, defaultValue?, rules?, value? (reactive string) | items\*, bind? | S (name vs bind; defaultValue/rules missing) |
| RadioItem | label\*, description\*, value\* | label\*, value? | G (description missing; value required→optional) |
| SwitchGroup | name\*, items\*, variant? (clear/card/sunk), value? (reactive record) | items\*, bind? | S (name vs bind; variant missing) |
| SwitchItem | label?, description?, name\*, defaultChecked? | label\*, value? | S (name-based vs label+value) |
| Chips | name\*, type='multiple', items=[], rules?, defaultValue? (string\|string[]) | items\*, bind? | S (name/type/defaultValue vs bind) |
| ChipItem | value\*, label\*, icon? (Icon ref), disabled? | label\*, value? | O + G (order swapped; icon/disabled missing) |
| OptionCards | name\*, type='single', items=[], rules?, defaultValue? | items\*, bind? | S (name/type/defaultValue vs bind) |
| OptionCard | value\*, title\*, subtitle?, topContent? (Icon\|Image ref), disabled? | label\*, value?, description? | S (value-first; title/subtitle/topContent vs label/description) |
| Button | label\*, action?, variant? (primary/secondary/tertiary), type? (normal/destructive), size? (extra-small/small/medium/large) | label\*, action? | G (variant/type/size missing) |
| Buttons | buttons\* (Button refs), direction? (row/column) | children\* (node list) | G + name (buttons→children; direction missing) |
| IconButton | name\*, icon\* (Icon ref), action?, variant?, size?, shape? (square/circle) | icon\* (string), action? | S (name missing; icon ref vs string; variant/size/shape missing) |
| FollowUpBlock (chat only) | items\* | items\* | P |
| FollowUpItem (chat only) | text\* | text\* | P |
| ListBlock | items\*, variant? (number/image), size? (default/small) | items\* | G (variant/size missing) |
| ListItem | title\*, subtitle?, image? ({src\*, alt\*}), actionLabel?, action? | text\* | S (title/subtitle/image/action vs single text) |
| SnippetCardBlock | items\* (min 2), layout='grid', responsive=true, action?, gap? | title?, items\* (as `SnippetBlock`) | G + X + name (title extra; layout/responsive/action/gap missing) |
| SnippetCardItem | id?, lhs\* (IconText\|ImageText), rhs? (Text\|BoldText) | text\*, action? (as `SnippetItem`) | S + name (lhs/rhs slots vs text/action) |
| OverviewCardBlock | items\* (min 2), layout='grid', responsive=true, action?, gap? | title?, items\* (as `OverviewBlock`) | G + X + name |
| OverviewCardItem | id?, top\* (IconText\|ImageText\|Text), bottom? (MetricIndicatorInline) | text\*, action? (as `OverviewItem`) | S + name |
| ContextCardBlock | items\* (min 2), layout='grid', responsive=true, action?, gap? | title?, items\* (as `ContextBlock`) | G + X + name |
| ContextCardItem | id?, title\* (string\|Tag), body?, bgColor? (gray), bgImageSrc?, bgImageAlt? | text\*, action? (as `ContextItem`) | S + name |
| CompositeCardBlock | items\* (min 2), layout='grid', responsive=true, action?, gap? | title?, items\* (as `CompositeBlock`) | G + X + name |
| CompositeCardItem | id?, header?, body=[] (Text/BoldText/Metric/IconText/Image/charts/ListBlock/TagBlock/EntityList), footer? ({price?, button?}) | text\*, action? (as `CompositeItem`) | S + name |
| VisualCardBlock | items\* (min 2), layout='grid', responsive=true, action?, gap? | title?, items\* (as `VisualBlock`) | G + X + name |
| VisualCardItem | body\* (BoldText ref), id?, bgImageSrc?, tag? (Tag ref), bgImageAlt? | text\*, src?, action? (as `VisualItem`) | S + name (body BoldText vs text; bgImageSrc vs src; tag vs action) |

### Settled example-level gaps (D1–D5, now schema-confirmed)

- **D1 — Stack:** confirmed. All five flex props are schema props
  (optional); Flutter `Stack` has none. A React program using
  `direction: "row"` / `wrap: true` cannot be expressed in Flutter.
- **D2 — TabItem / Input:** confirmed as built-in schemas, not
  illustrations. TabItem is (value, trigger, content); Input is (name,
  placeholder?, type?, rules?, value?).
- **D3 — Col third positional:** confirmed: `type` enum(string, number,
  action). Flutter `Col` lacks it, and its second prop is named `values`
  where React's is `data`.
- **D4 — Tag:** confirmed: (text, icon?, size?, variant?). Flutter's
  second slot is a string icon name where React's is an Icon ref, and
  Flutter has no size/variant.
- **D5 — Form / FormControl (largest structural divergence):**
  confirmed: `Form(name, buttons, fields)`,
  `FormControl(label, input, hint)` with a single field ref (and
  SwitchGroup excluded from the union). React Form programs are not
  portable to Flutter as written, and vice versa. Side note: the
  general-library group note calls Buttons "the third Form argument"
  while the chat-library note calls it "the second" with the matching
  example `Form(name, buttons, fields)` — the schema order agrees with
  the chat note; the general note is inconsistent with its own schema.

### Props Flutter has that React lacks (X-list, from the table above)

- All five card blocks: `title` (React blocks have no title prop).
- `MetricIndicatorInline` / `MetricIndicatorWithStrikethrough`: `label`
  (React has no label; value is a bare string).
- `ImageBlock`: `caption` (React has `alt` instead).
- All form fields and selection groups: `bind` (React fields are
  `name`-keyed; there is no bind prop) — and `label` on Input/TextArea/
  Select/DatePicker/Slider (React fields carry `name`, not `label`).
- `CheckBoxItem` / `SwitchItem`: `value` (React items are `name`-keyed
  with `description`/`defaultChecked`, no value prop).
- `SectionBlock`: `title` (React has `sections` + `isFoldable`).
- `Slider`: declared defaults `min=0`, `max=100` (React requires min/max
  with no defaults) — leniency, not a new prop, but a contract
  difference: a React program omitting min/max is invalid; a Flutter
  program omitting them renders 0–100.
- `TextContent`: the `variant` value `'normal'` is not a React size
  value (React: small/default/large/small-heavy/large-heavy).

### Host primitives with verified props (NOT GenUI — do not count in the 86)

Unchanged by the source read (these live outside genui-lib; tables from
the fetched API-reference page):

| Primitive | React (documented) | Flutter host widget | Divergence |
| --- | --- | --- | --- |
| `Skeleton` | `count=1`, `height="16px"`, `width="100%"`, `borderRadius` → `--openui-radius-xs` | `count=3`, `color` → grey300, 16px bars | Default count 3 vs 1; no `height`/`width`/`borderRadius` params |
| `TableSkeleton` | `rows=5`, `columns=4` | `columns=3`, `rows=4` | Defaults swapped in magnitude (5×4 vs 4×3) |
| `Citation` / `Sources` | 0.17-era primitives; props not documented on fetched pages | `Citation(index*, title*, url?, onTap?)`; `Sources(items*)` with `SourceItem(title, url?, faviconUrl?)` | Flutter `Sources` row tap is a no-op and `url` is never opened by the widget itself; `Citation.url` likewise carried but never navigated. Related GenUI gap: chat `Card.sources` ([{title, sourceName, url}]) has no Flutter `Card` equivalent. |

## (e) Flutter-internal notes (NOT React gaps)

Carried over from `flutter-inventory.md`. These are findings about the
Flutter port itself; none of them implies a React component is missing or
a React prop is wrong.

- **F1 — `CodeBlock.language` declared but never read.** The renderer reads
  only `code` and renders plain monospace text. This is the deliberate
  post-revert state (syntax_highlight implemented then reverted by user
  decision; CodeBlock stays plain text until a new highlighting decision).
  A program passing a language gets it accepted and silently ignored.
  (New source context: React's `language` is REQUIRED and FIRST, so the
  Flutter declaration order and requiredness both differ too — see §d.)
- **F2 — `Image.alt` only partially used.** Never used as an accessibility
  label/semantics; its only use is as the error-placeholder text
  (`stringOf('alt', '图片加载失败')`) — shown only when the network image
  fails, and showing '图片加载失败' when alt is absent.
- **F3 — Composite-item `src` dead read.** The five composite item types
  share one renderer case reading `props['src']` for a leading image, but
  only `VisualItem` declares `src`. For `SnippetItem` / `OverviewItem` /
  `ContextItem` / `CompositeItem` a program cannot supply `src` through the
  Lang mapper (a third positional is an `excess-args` error and is
  ignored), so the read is dead code for those four types. Harmless, but
  the shared case implies an API the defs do not offer.
- **F4 — 12 parent-read-only components (by design, not a bug).** `Col`,
  `Series`, `Slice`, `ScatterSeries`, `Point`, `SelectItem`, `ChipItem`,
  `FollowUpItem`, `CheckBoxItem`, `RadioItem`, `SwitchItem`, `OptionCard`
  have no dedicated renderer case; standalone they render
  `SizedBox.shrink`, and each is read by its parent component. No
  registered component is entirely unhandled (F5: none registered-but-
  unrendered; F6: no other renderer-read-but-undeclared props).
- **F7 — Renderer-side fallbacks that differ in spirit from the declared
  contract (notes, not errors).** Select/Chip/CheckBox/Radio/Switch/
  OptionCard `value` falls back to the item's `label` when absent;
  Input/TextArea `value` is only the initial value (bound state wins);
  Slider value chain is form-state → `value` → `min` → 0.0;
  CalendarHeatmap entries with unparseable `date` or non-num `value` are
  silently skipped; Series non-numeric entries become 0, Slice `value` /
  Point `x`/`y` become 0 via `numOf`.
- **Declared defaults are rare.** Only four props in the whole Flutter
  library declare a default: `TextContent.variant = 'normal'`,
  `Callout`/`TextCallout.variant = 'info'`, `Slider.min = 0`,
  `Slider.max = 100`. Every other fallback is renderer-side leniency
  (`stringOf` → `''`, `nodesOf` → `[]`, `numOf` → `0`), not a declared
  default — so "required" in §d means the mapper rejects an omitted prop,
  not that the renderer throws. Contrast React, where `.default(...)`
  is common (card-block layout/responsive, Chips/OptionCards type and
  items, EntityList size, IconText variants, EditableTable name/columns/
  data, Form fields).

## Remaining caveats (what the checkout could NOT establish)

1. `Icon.category`: existence confirmed (description + renderer), exact
   Zod type not established — the schema file lives outside the sparse
   checkout.
2. Positional call shape for `Text` / `BoldText`: first schema key is a
   defaulted enum (`variant`) and no repo example shows a positional
   `Text(...)` call; their §d verdicts are by NAME, not by position.
3. Whether the 6 non-Condensed extras exist as non-GenUI UI primitives
   under `packages/react-ui/src/components`, and the full `Icon`
   schema — not checkable from the sparse checkout; not guessed here.
4. The 0.17.0 → 0.18.1 rename question (were the 11 long names already
   GenUI names in 0.17?) — needs the 0.17 source, not in this checkout.
5. react-lang's own arg-mapping rules (positional vs named) live outside
   genui-lib; the positional reading used here rests on the repo's own
   group-note examples, not on the react-lang source.

## What would close the remaining gaps

1. **Decide the 11 renames** (alias vs rename) — the cheapest fix in this
   report, and the only one that changes `unknown-component` failures
   for existing React programs. An alias table (old short name → new
   long name) preserves Flutter programs while accepting React ones.
2. **Decide the Form shape** (D5) — the largest structural divergence; it
   determines whether Form programs are portable at all. Note the
   Flutter `bind` model vs React's `name` model is a second, deeper
   form-system divergence behind the same decision.
3. **Reconcile the two libraries** — either split Flutter's single library
   into general + chat variants or document the merged library as a
   deliberate deviation (including the missing chat-`Card.sources`).
4. **Props alignment pass** over §d's 75 gap/shape rows, in priority
   order: charts (labels vs categories; Pie/Radial/SingleStacked
   labels+values vs slices), card blocks (item-slot shapes), form fields
   (name vs label+bind), then the long tail of optional styling props
   (variant/size/direction/flex).
5. **Residual source checks** (small): full `Icon` schema from
   `components/_shared/icons`, react-lang arg mapping for `Text` /
   `BoldText`, 0.17 tag source for the rename question.

## Sources

Inputs (read fully for this diff):

- `react-source-props.md` — React side, read from genui-lib source at
  HEAD `f08a660535e55b5b2a24a0eb68568edaf9e4fe4b`, react-ui 0.18.1.
- `react-inventory.md` — earlier official side; Lang 1.0 spec + react-ui
  0.18.1 (superseded on props by the source read above).
- `flutter-inventory.md` — Flutter side; HEAD `9b22cd8`, 95 components.

Official sources fetched for earlier rounds (2026-10-28):

- https://github.com/thesysdev/openui/tree/main/packages/react-ui — package
  README at `main` (0.18 category table incl. `MarkDownRenderer`, `...`
  chart tail, peer deps, subpath exports).
- https://docs.langchain.com/oss/python/langchain/frontend/integrations/openui
  — LangChain OpenUI docs (no component signatures; confirms
  `openuiLibrary.prompt()` system-prompt flow).
- https://www.openui.com/docs/api-reference/react-ui — `AgentInterface`
  props, two libraries, `Skeleton` / `TableSkeleton` prop tables.
- https://www.openui.com/docs/openui-lang/defining-components — Form /
  FormControl prompt signatures, `defineComponent` / `createLibrary`.
- https://www.openui.com/docs/openui-lang/specification — Lang 1.0 spec,
  action table, error codes, stored-message format.
- https://www.openui.com/docs/openui-lang/functions — 14 built-in functions.
- https://www.openui.com/docs/openui-lang/whats-new — Lang 1.0 additions.
- https://www.openui.com/docs/openui-lang/system-prompts — prompt generation.
- https://www.openui.com/docs/api-reference/react-lang — runtime API.
- https://www.openui.com/docs/openui-lang/quickstart — library roots.
- https://www.jsdelivr.com/package/npm/@openuidev/react-ui — version 0.18.1.
