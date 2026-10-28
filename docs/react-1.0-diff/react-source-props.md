# React GenUI source props — ground truth from genui-lib source

- **Source:** `thesysdev/openui`, `packages/react-ui/src/genui-lib`, HEAD
  `f08a660535e55b5b2a24a0eb68568edaf9e4fe4b` (commit `f08a660 chore: version
  packages (#1461)`), package `@openuidev/react-ui` version **0.18.1**,
  rendering OpenUI Lang 1.0. Read from a local sparse checkout of
  `genui-lib` only; this file is self-contained and does not depend on it.
- **What "registered name" means:** the `name:` string in each component's
  `defineComponent({...})` call — that is the identifier a Lang program
  invokes, and it is NOT always the same as the file/export name. The
  cases where they differ are called out in §1.
- **How to read the tables:** props are listed in **schema declaration
  order**. `Req` = the Zod key has neither `.optional()` nor `.default()`
  (a Lang program must supply it). `Opt` = `.optional()` (may be omitted).
  `Opt (default X)` = `.default(X)` (may be omitted; X is applied).
  `reactive(...)` = a react-lang reactive wrapper around the inner type;
  requiredness follows the inner type. `ref(X)` = a reference to another
  GenUI component X (the value is an X node, not a plain value).
  `z.any()` / `z.unknown()` are written as `any` / `unknown`.
  Enum value lists are given in full.
- **Positional mapping (why schema order matters):** Lang component calls
  in the repo's own group notes are positional in schema order, e.g.
  `Tag(t.priority, null, "sm")` = text/icon/size, `Col("Sales", sales,
  "number")` = label/data/type, `Callout("success", "Saved", "Done.",
  $showSuccess)` = variant/title/description/visible, `Form("edit",
  Buttons([saveBtn, cancelBtn]), [fields...])` = name/buttons/fields.
  The Flutter port's mapper is also positional in declaration order, so
  §d verdicts in `react-flutter-diff.md` compare slot-by-slot in this
  order. One caveat: for components whose FIRST schema key carries a
  default (`Text`/`BoldText` `variant`), no repo example confirms the
  positional call shape — see §4.
- **Scope limits (read before quoting):** (1) `Icon`'s schema is re-exported
  from `packages/react-ui/src/components/_shared/icons`, which is OUTSIDE
  the sparse checkout: only `name` (required — the renderer returns null
  without it) and `category` (optional, per the component description) are
  established; any further Icon fields are NOT established here.
  (2) Whether `HeatmapChart` / `FunnelChart` / `CalendarHeatmap` / Mini
  charts / `StackedLegend` / `SegmentedBar` exist as standalone UI
  primitives under `packages/react-ui/src/components` could NOT be checked
  — that directory is outside the sparse checkout. What IS established is
  that none of them is a registered GenUI name (zero hits across the whole
  checkout). (3) The 0.17.0 → 0.18.1 delta cannot be established from this
  checkout alone (no 0.17 source in it).

## 1. Registered names and library membership

**Distinct registered GenUI names: 86.** General library
(`openuiLibrary`, root `Stack`): **82**. Chat library
(`openuiChatLibrary`, root `Card`): **84**. Shared by both: 80.
General-only: `Stack`, `Modal`. Chat-only: `FollowUpBlock`,
`FollowUpItem`, `SectionBlock`, `SectionItem`.

**Export name ≠ registered name (3 cases, all in Charts/):**
`BarChartCondensed.ts` registers `BarChart`, `LineChartCondensed.ts`
registers `LineChart`, `AreaChartCondensed.ts` registers `AreaChart`.
There is NO GenUI name `BarChartCondensed` / `LineChartCondensed` /
`AreaChartCondensed` — the "Condensed" files ARE the Bar/Line/Area chart
implementations.

**Chat-variant components (same registered name, different schema):**
`Card` (chat: `children`, `sources?`; general: `children`, `variant?` +
flex props), `Tabs` / `TabItem` / `Accordion` / `AccordionItem` /
`Carousel` / `SectionBlock` / `SectionItem` (chat variants accept the
wider chat content union; the general `Tabs`/`TabItem`/`Accordion`/
`AccordionItem`/`Carousel` schemas are the ones tabled in §2, and the
chat `SectionBlock`/`SectionItem` schemas are tabled in §2 because the
general library does not register them at all). Note: the standalone
`SectionItem` component defined in `SectionItem/index.tsx`
(value/trigger/content over `sectionContentUnion`) is NOT in either
library's component list — the registered `SectionItem` is the chat
variant defined in `openuiChatLibrary.tsx` (same three props, wider
content union).

**General library (82):** Stack, Tabs, TabItem, Accordion, AccordionItem,
Steps, StepsItem, Carousel, Separator, Modal, Card, CardHeader,
TextContent, MarkDownRenderer, Callout, TextCallout, Image, ImageBlock,
ImageGallery, CodeBlock, InlineHeader, Table, Col, EditableTable,
BarChart, LineChart, AreaChart, RadarChart, HorizontalBarChart, Series,
PieChart, RadialChart, SingleStackedBarChart, Slice, ScatterChart,
ScatterSeries, Point, Form, FormControl, Label, Input, TextArea, Select,
SelectItem, DatePicker, Slider, CheckBoxGroup, CheckBoxItem, RadioGroup,
RadioItem, SwitchGroup, SwitchItem, Chips, ChipItem, OptionCards,
OptionCard, Button, Buttons, IconButton, TagBlock, Tag, Icon, EntityList,
ListBlock, ListItem, Text, BoldText, IconText, ImageText, ImageTextLarge,
MetricIndicatorInline, MetricIndicatorWithStrikethrough,
SnippetCardBlock, SnippetCardItem, OverviewCardBlock, OverviewCardItem,
ContextCardBlock, ContextCardItem, CompositeCardBlock, CompositeCardItem,
VisualCardBlock, VisualCardItem.

**Chat library (84):** everything above EXCEPT Stack and Modal, PLUS
FollowUpBlock, FollowUpItem, SectionBlock, SectionItem (and the chat
variants of Card/Tabs/TabItem/Accordion/AccordionItem/Carousel/
SectionBlock/SectionItem).

**NOT registered GenUI names (zero hits as a GenUI registration in the
checkout):** `HeatmapChart`, `FunnelChart`, `CalendarHeatmap`,
`MiniBarChart`, `MiniLineChart`, `StackedLegend`, `SegmentedBar`,
`SingleStackedBar` (the last appears only as a UI-primitive import,
`SingleStackedBar as SingleStackedBarChartComponent`, inside
`Charts/SingleStackedBarChart.ts` — it is the underlying chart widget,
not a Lang-invocable name). `SourceFaviconImage`, `ToolCall`,
`ToolResult`, `AgentInterface` are likewise not GenUI registrations.

## 2. Per-component React schema props

Shared flex props (merged into `Stack` and general `Card`):
`direction?` enum(row, column), `gap?` enum(none, xs, s, m, l, xl, 2xl),
`align?` enum(start, center, end, stretch, baseline), `justify?`
enum(start, center, end, between, around, evenly), `wrap?` boolean.
Renderer fallbacks (NOT schema defaults): direction → "column",
gap → "m". The general `Card` additionally merges these; the chat
`Card` does not.

Shared validation-rules object (`rules`, itself optional): `required?`
boolean, `email?` boolean, `url?` boolean, `numeric?` boolean, `min?`
number, `max?` number, `minLength?` number, `maxLength?` number,
`pattern?` string.

### Layout

**Stack** (general only) — `children` Req array(any); + flex props above
(all Opt).

**Tabs** — `items` Req array(ref(TabItem)).

**TabItem** — `value` Req string, `trigger` Req string, `content` Req
array(ContentChildUnion). Chat variant: same three props, content over
the wider chat union (adds ChatAccordion ref).

**Accordion** — `items` Req array(ref(AccordionItem)).

**AccordionItem** — `value` Req string, `trigger` Req string, `content`
Req array(ContentChildUnion). Chat variant: same three props, content
over the wider chat union.

**Steps** — `items` Req array(ref(StepsItem)).

**StepsItem** — `title` Req string, `details` Req string.

**Carousel** — `children` Req array(array(ContentChildUnion)) (each inner
array is one slide), `variant?` enum(card, sunk). Chat variant: same.

**Separator** — `orientation?` enum(horizontal, vertical),
`decorative?` boolean.

**Modal** (general only) — `title` Req string, `open?`
reactive(boolean), `children` Req array(ContentChildUnion), `size?`
enum(sm, md, lg).

**SectionBlock** (chat only) — `sections` Req array(ref(SectionItem)),
`isFoldable?` boolean.

**SectionItem** (chat only) — `value` Req string, `trigger` Req string,
`content` Req array(union: chat content + Tabs ref + Accordion ref).

### Content

**Card** (general) — `children` Req array(CardChildUnion), `variant?`
enum(card, sunk, clear), + flex props above.

**Card** (chat) — `children` Req array(ChatCardChildUnion), `sources?`
array({title, sourceName, url}) — renders a Sources strip and backs
inline [n] citations in TextContent.

**CardHeader** — `title?` string, `subtitle?` string. (Both optional.)

**TextContent** — `text` Req string, `size?` enum(small, default, large,
small-heavy, large-heavy).

**Text** — `variant` Opt (default "text") enum(text, number), `value`
Req string, `subtext?` string, `subtextVariant` Opt (default "text")
enum(text, number, metric), `size` Opt (default "sm") enum(xs, sm, md,
lg).

**BoldText** — identical shape to `Text`: `variant` Opt (default
"text"), `value` Req string, `subtext?` string, `subtextVariant` Opt
(default "text"), `size` Opt (default "sm").

**MarkDownRenderer** — `textMarkdown` Req string, `variant?`
enum(clear, card, sunk). (Spelling with capital D is the registered
name.)

**Callout** — `variant` Req enum(info, warning, error, success,
neutral), `title` Req string, `description` Req string, `visible?`
reactive(boolean).

**TextCallout** — `variant?` enum(neutral, info, warning, success,
danger), `title?` string, `description?` string. (All optional.)

**Image** — `alt` Req string, `src?` string. (alt required, src
optional — the reverse of the usual assumption.)

**ImageBlock** — `src` Req string, `alt?` string.

**ImageGallery** — `images` Req array({src Req string, alt? string,
details? string}).

**ImageText** — `src` Req string, `alt?` string, `title` Req string,
`subtitle?` string, `bold` Opt (default false) boolean, `layout` Opt
(default "horizontal") enum(horizontal, vertical), `imageSize?`
number.

**ImageTextLarge** — `src` Req string, `alt?` string, `title` Req
string, `subtitle?` string, `bold` Opt (default false) boolean.

**IconText** — `icon` Req ref(Icon), `iconVariant` Opt (default
"neutral") enum(neutral, info, success, warning, danger, inverted,
filled, soft), `iconSize` Opt (default "m") enum(xs, s, m, l, xl, sm,
md, lg), `title` Req string, `subtitle?` string, `bold` Opt (default
false) boolean, `layout` Opt (default "horizontal") enum(horizontal,
vertical).

**CodeBlock** — `language` Req string, `codeString` Req string.
(Language FIRST, code second; both required.)

**InlineHeader** — `heading` Req string, `description?` string.

**Icon** — `name` Req string (lucide icon by kebab-case name; renderer
returns null when absent), `category?` (per component description:
"optional category picks a topical fallback when the name doesn't
resolve"). Exact Zod shape of `category` NOT established (schema lives
outside the sparse checkout — see scope limits).

### Tables

**Table** — `columns` Req array(ref(Col)).

**Col** — `label` Req string, `data` Req any (array of values OR
component nodes, one per row), `type?` enum(string, number, action).

**EditableTable** — `name` Opt (default "") string, `columns` Opt
(default []) array({type Req enum(text, number, date-single, select,
url), key Opt (default "default") string, header Opt (default "")
string, width? number, options? array({value Req string, label Req
string})}), `data` Opt (default []) array({id Req string, values Req
array(string | number)}). All three props are optional-with-default;
edited data is submitted on "Save Changes", keyed by `name`.

### Charts

**BarChart** (from `BarChartCondensed.ts`) — `labels` Req
array(string), `series` Req array(SeriesSchema), `variant?`
enum(grouped, stacked), `xLabel?` string, `yLabel?` string, `height?`
number.

**LineChart** (from `LineChartCondensed.ts`) — `labels` Req
array(string), `series` Req array(SeriesSchema), `variant?`
enum(linear, natural, step), `xLabel?` string, `yLabel?` string,
`height?` number.

**AreaChart** (from `AreaChartCondensed.ts`) — `labels` Req
array(string), `series` Req array(SeriesSchema), `variant?`
enum(linear, natural, step), `xLabel?` string, `yLabel?` string,
`height?` number.

**RadarChart** — `labels` Req array(string), `series` Req
array(SeriesSchema).

**HorizontalBarChart** — `labels` Req array(string), `series` Req
array(SeriesSchema), `variant?` enum(grouped, stacked), `xLabel?`
string, `yLabel?` string.

**Series** — `category` Req string, `values` Req array(number).

**PieChart** — `labels` Req array(string), `values` Req array(number),
`variant?` enum(pie, donut), `appearance?` enum(circular,
semiCircular). (Labels + values arrays — NOT Slice nodes.)

**RadialChart** — `labels` Req array(string), `values` Req
array(number).

**SingleStackedBarChart** — `labels` Req array(string), `values` Req
array(number). (Labels + values arrays — NOT Slice nodes.)

**Slice** — `category` Req string, `value` Req number. (A virtual
component: used inside chart data contexts, not a standalone chart.)

**ScatterChart** — `datasets` Req array(ScatterSeriesSchema),
`xLabel?` string, `yLabel?` string.

**ScatterSeries** — `name` Req string, `points` Req
array(PointSchema).

**Point** — `x` Req number, `y` Req number, `z?` number.

### Data display

**TagBlock** — `tags` Req array(string), `size?` enum(sm, md, lg).
(Takes plain strings, NOT Tag nodes.)

**Tag** — `text` Req string, `icon?` ref(Icon), `size?` enum(sm, md,
lg), `variant?` enum(neutral, info, success, warning, danger).

**EntityList** — `rows` Req array({left Req string, right Req string,
rightVariant Opt (default "text") enum(text, number)}), `size` Opt
(default "default") enum(small, default), `header?` row object,
`footer?` row object. Refined: size "small" forbids header/footer.

**MetricIndicatorInline** — `value` Req string, `subtext?` string,
`trend?` {direction Req enum(up, down), value Req number}.

**MetricIndicatorWithStrikethrough** — `value` Req string, `subtext?`
string, `previousValue?` string, `trend?` {direction Req enum(up,
down), value Req number}.

**ListBlock** — `items` Req array(ref(ListItem)), `variant?`
enum(number, image), `size?` enum(default, small).

**ListItem** — `title` Req string, `subtitle?` string, `image?`
{src Req string, alt Req string}, `actionLabel?` string, `action?`
action.

**FollowUpBlock** (chat only) — `items` Req array(ref(FollowUpItem)).

**FollowUpItem** (chat only) — `text` Req string.

### Forms

**Form** — `name` Req string, `buttons` Req ref(Buttons), `fields`
Opt (default []) array(ref(FormControl)). Note: the general-library
group note says "pass a Buttons(...) reference as the third Form
argument" while the chat-library note says "the second Form argument:
Form(name, buttons, fields)" — the schema order (name, buttons,
fields) agrees with the chat note; the general note's "third" is
inconsistent with its own schema and the schema wins.

**FormControl** — `label` Req string, `input` Req union(ref(Input),
ref(TextArea), ref(Select), ref(DatePicker), ref(Slider),
ref(CheckBoxGroup), ref(RadioGroup), ref(Chips), ref(OptionCards)),
`hint?` string. NOTE: `SwitchGroup` is NOT in the input union.

**Label** — `text` Req string.

**Input** — `name` Req string, `placeholder?` string, `type?`
enum(text, email, password, number, url), `rules?` rules object,
`value?` reactive(string).

**TextArea** — `name` Req string, `placeholder?` string, `rows?`
number, `rules?` rules object, `value?` reactive(string).

**Select** — `name` Req string, `items` Req array(ref(SelectItem)),
`placeholder?` string, `rules?` rules object, `value?`
reactive(string), `size?` enum(small, medium, large).

**SelectItem** — `value` Req string, `label` Req string. (Value FIRST.)

**DatePicker** — `name` Req string, `mode?` enum(single, range),
`rules?` rules object, `value?` reactive(unknown).

**Slider** — `name` Req string, `variant` Req enum(continuous,
discrete), `min` Req number, `max` Req number, `step?` number,
`defaultValue?` array(number), `label?` string, `rules?` rules
object, `value?` reactive(array(number)). (Value is an ARRAY of
numbers; min/max/variant are required, with no schema defaults.)

**CheckBoxGroup** — `name` Req string, `items` Req
array(ref(CheckBoxItem)), `rules?` rules object, `value?`
reactive(record(string, boolean)).

**CheckBoxItem** — `label` Req string, `description` Req string,
`name` Req string, `defaultChecked?` boolean.

**RadioGroup** — `name` Req string, `items` Req array(ref(RadioItem)),
`defaultValue?` string, `rules?` rules object, `value?`
reactive(string).

**RadioItem** — `label` Req string, `description` Req string, `value`
Req string.

**SwitchGroup** — `name` Req string, `items` Req
array(ref(SwitchItem)), `variant?` enum(clear, card, sunk), `value?`
reactive(record(string, boolean)).

**SwitchItem** — `label?` string, `description?` string, `name` Req
string, `defaultChecked?` boolean.

**Chips** — `name` Req string, `type` Opt (default "multiple")
enum(single, multiple), `items` Opt (default []) array(ref(ChipItem)),
`rules?` rules object, `defaultValue?` string | array(string).

**ChipItem** — `value` Req string, `label` Req string, `icon?`
ref(Icon), `disabled?` boolean. (Value FIRST.)

**OptionCards** — `name` Req string, `type` Opt (default "single")
enum(single, multiple), `items` Opt (default []) array(ref(OptionCard)),
`rules?` rules object, `defaultValue?` string | array(string).

**OptionCard** — `value` Req string, `title` Req string, `subtitle?`
string, `topContent?` union(ref(Icon), ref(Image)), `disabled?`
boolean. (Value FIRST.)

### Actions

**Button** — `label` Req string, `action?` action, `variant?`
enum(primary, secondary, tertiary), `type?` enum(normal, destructive),
`size?` enum(extra-small, small, medium, large).

**Buttons** — `buttons` Req array(ref(Button)), `direction?`
enum(row, column).

**IconButton** — `name` Req string, `icon` Req ref(Icon), `action?`
action, `variant?` enum(primary, secondary, tertiary), `size?`
enum(extra-small, small, medium, large), `shape?` enum(square, circle).

### Card blocks

All five blocks share: `items` Req array(ref(Item)) with `.min(2)`,
`layout` Opt (default "grid") enum(grid, carousel) — SnippetCardBlock
only enum(grid) — `responsive` Opt (default true) boolean, `action?`
action, `gap?` number | string. None of the five blocks has a `title`
prop.

**SnippetCardBlock** — items of SnippetCardItem. **SnippetCardItem** —
`id?` string, `lhs` Req union(ref(IconText), ref(ImageText)), `rhs?`
union(ref(Text), ref(BoldText)).

**OverviewCardBlock** — items of OverviewCardItem.
**OverviewCardItem** — `id?` string, `top` Req union(ref(IconText),
ref(ImageText), ref(Text)), `bottom?` ref(MetricIndicatorInline).

**ContextCardBlock** — items of ContextCardItem. **ContextCardItem** —
`id?` string, `title` Req union(string, ref(Tag)), `body?` string,
`bgColor?` enum(gray), `bgImageSrc?` string, `bgImageAlt?` string.

**CompositeCardBlock** — items of CompositeCardItem.
**CompositeCardItem** — `id?` string, `header?` union(ref(IconText),
ref(ImageText), ref(ImageTextLarge), ref(Text), ref(Image)),
`body` Opt (default []) array(union(ref(Text), ref(BoldText),
ref(MetricIndicatorInline), ref(IconText), ref(Image), ref(AreaChart),
ref(BarChart), ref(LineChart), ref(ListBlock), ref(TagBlock),
ref(EntityList))), `footer?` {price? union(ref(BoldText),
ref(MetricIndicatorWithStrikethrough)), button? ref(Button)}.

**VisualCardBlock** — items of VisualCardItem. **VisualCardItem** —
`body` Req ref(BoldText), `id?` string, `bgImageSrc?` string, `tag?`
ref(Tag), `bgImageAlt?` string.

## 3. Resolved open questions (from the earlier diff)

- (a) CardBlock names: registered names KEEP the `Card` suffix —
  `SnippetCardBlock` / `SnippetCardItem`, `OverviewCardBlock` /
  `OverviewCardItem`, `ContextCardBlock` / `ContextCardItem`,
  `CompositeCardBlock` / `CompositeCardItem`, `VisualCardBlock` /
  `VisualCardItem`. Flutter's short names (`SnippetBlock`, `SnippetItem`,
  …) do NOT match any registered name. The earlier report's "0.17 doc
  records longer names while GenUI-facing names govern" is contradicted
  by source: the GenUI-facing names ARE the long names.
- (b) MarkDownRenderer casing: confirmed from source —
  `defineComponent({ name: "MarkDownRenderer", ... })` and
  `MarkDownRendererSchema` with `textMarkdown`. Flutter's
  `MarkdownRenderer` is a different identifier.
- (c) SingleStackedBar: the registered name is
  `SingleStackedBarChart` (labels + values arrays). `SingleStackedBar`
  is only the underlying chart widget imported from outside genui-lib;
  `SegmentedBar` has zero hits in the checkout and is not a GenUI name.
- (d) The 9 Flutter extras: NONE is a registered GenUI name in this
  checkout. `BarChartCondensed` / `LineChartCondensed` /
  `AreaChartCondensed` are Flutter-only NAMES (the React files of those
  names register `BarChart` / `LineChart` / `AreaChart`).
  `HeatmapChart` / `FunnelChart` / `CalendarHeatmap` / `MiniBarChart` /
  `MiniLineChart` / `StackedLegend` have zero hits anywhere in the
  checkout; whether they exist as non-GenUI UI primitives outside
  genui-lib could not be checked from the sparse checkout.
- (e) 0.18 vs 0.17 baseline: the registered set is 86 names — the same
  COUNT as the 0.17 baseline, but 11 of the baseline's identifiers are
  wrong (1 casing + 10 Card-suffix names). Whether those 11 are 0.18
  renames or were already the 0.17 GenUI names cannot be established
  from this checkout (no 0.17 source in it); the old "0 missing" verdict
  therefore falls regardless, because it was measured against the wrong
  identifiers.
- (f) Form shape (D5): settled — `Form(name, buttons, fields)`,
  `FormControl(label, input, hint)` with `input` a single field ref
  (SwitchGroup excluded from the union). Flutter's
  `Form(children)` / `FormControl(label, children, hint)` is
  structurally different.
- D1 Stack: settled — direction/gap/align/justify/wrap are all optional
  schema props; Flutter has none of them.
- D2 TabItem/Input: settled — TabItem is (value, trigger, content);
  Input is (name, placeholder?, type?, rules?, value?). Neither was an
  illustration; both are the built-in schemas.
- D3 Col: settled — third positional is `type` enum(string, number,
  action); second is `data` (any), not `values`.
- D4 Tag: settled — Tag is (text, icon?, size?, variant?); the example
  `Tag(t.priority, null, "sm")` is exactly text/icon/size.

## 4. Remaining caveats (honest, per item)

- Icon `category`: existence established (description + renderer), exact
  Zod type NOT established (schema outside checkout).
- Positional call shape for `Text` / `BoldText`: first schema key is a
  defaulted enum (`variant`), and no repo example shows a positional
  `Text(...)` call; if react-lang maps strictly in schema order, a
  one-argument `Text("...")` would bind to `variant`, so either the
  prompt instructs a different call shape or mapping skips defaulted
  keys — not resolvable from the genui-lib checkout (react-lang is
  outside it). Verdicts for Text/BoldText are by NAME, not by position.
- Standalone-primitive existence outside genui-lib (Heatmap etc. as UI
  widgets, `SingleStackedBar` widget props, `SegmentedBar` anywhere,
  Icon's full schema, chat `Card` sources rendering details beyond the
  prop type) — not checkable from this checkout; stated per item above,
  not guessed.
- Host primitives `Skeleton` / `TableSkeleton` / `Citation` / `Sources`
  are NOT in genui-lib and are not tabled here; their previously
  documented prop tables (API-reference page) are unchanged by this
  source read.
