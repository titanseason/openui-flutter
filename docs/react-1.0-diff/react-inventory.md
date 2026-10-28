# React inventory — official `@openuidev/react-ui` GenUI library (for Flutter diff)

## Header

- **Basis (read this first): "Lang 1.0" is NOT "react-ui 1.0".**
  Lang 1.0 (spec updated 2026-10-26) is implemented by `@openuidev/lang-core` 1.0.1
  and `@openuidev/react-lang` 1.0.1, but the component package itself is still 0.x:
  **`@openuidev/react-ui` 0.18.1** (npm `latest`; jsDelivr lists `0.18.1`; the
  package README at `main` says "react-ui 0.18 renders OpenUI Lang 1.0").
  Any statement of the form "react-ui 1.0" is wrong for this inventory.
- **Fetch date:** 2026-10-28. Docs pages fetched carry the stamp
  `Updated: 2026-10-26T12:30:41.000Z`. Repo state at fetch: `thesysdev/openui`,
  default branch `main`, HEAD `f08a660535e55b5b2a24a0eb68568edaf9e4fe4b`, MIT.
- **Peer dependencies (0.18 README):** `react >=19.0.0`, `react-dom >=19.0.0`,
  `zustand ^4.5.5`, `zod ^3.25.0 || ^4.0.0`,
  `@openuidev/react-lang >=1.0.0 <2.0.0`, `@openuidev/react-headless`.
- **Import paths:** libraries from `@openuidev/react-ui/genui-lib`
  (`openuiLibrary`, `openuiChatLibrary`, plus `openuiPromptOptions`,
  `openuiExamples`, `openuiAdditionalRules`, `openuiComponentGroups` and the
  `openuiChat*` counterparts); styles from
  `@openuidev/react-ui/styles/index.css` (or the `layered/` variant).

## Sources

Official sources actually fetched for this inventory (all 2026-10-28):

1. https://www.openui.com/docs/api-reference/react-ui — `AgentInterface` props,
   the two libraries, `Skeleton`/`TableSkeleton` prop tables.
2. https://github.com/thesysdev/openui/tree/main/packages/react-ui — package
   README at `main` (component category table, subpath exports, peer deps).
3. https://www.openui.com/docs/openui-lang/defining-components — `defineComponent`
   / `createLibrary` semantics, component-group examples, `Form`/`FormControl`
   prompt signatures.
4. https://www.openui.com/docs/openui-lang/specification — Lang 1.0 spec, action
   table, error codes, stored-message format.
5. https://www.openui.com/docs/openui-lang/functions — the 14 built-in functions.
6. https://www.openui.com/docs/openui-lang/whats-new — what Lang 1.0 added.
7. https://www.openui.com/docs/openui-lang/system-prompts — prompt generation.
8. https://www.openui.com/docs/api-reference/react-lang — runtime API
   (`defineComponent`, `createLibrary`, `extend`, `Renderer`, error codes).
9. https://www.openui.com/docs/openui-lang/quickstart — library roots, chat setup.
10. https://www.jsdelivr.com/package/npm/@openuidev/react-ui — version 0.18.1,
    MIT, updated 2026-10-15.
11. https://ibl.ai/blog/openui-lang-1-0-what-shipped-version-coupling — third-party
    version matrix read from npm `latest` on 2026-10-16 (used ONLY for the
    version-matrix cross-check, not for component facts).
12. Prior research doc `~/workspace/your_files/openui-react-ui-components.html`
    (0.17.0 baseline, 2026-10-14) — used ONLY where marked "0.17-era", i.e.
    for the 86-name baseline and library-membership detail the current docs
    do not repeat. Where current docs and the 0.17 doc disagree, current docs win.

## Method and the central limitation (read before diffing)

- **The official docs publish no per-component prop reference for the built-in
  GenUI library as of 2026-10-28.** The docs link labelled "built-in component
  libraries" resolves to
  `https://www.openui.com/docs/api-reference/react-ui#component-library-exports`,
  which returns 404; the base API-reference page contains only the
  `AgentInterface` props and the `Skeleton`/`TableSkeleton` tables. The package
  README's component table is a simplified summary (it uses `...` for charts
  and omits several GenUI names entirely) — the 0.17 research doc already warned
  against treating README tables as complete.
- **Consequence, applied uniformly below:** for every component whose props are
  not documented on a fetched official page, the section says exactly
  "props not documented on <source>" instead of inventing a schema. Props that
  appear only in docs *examples* (sample programs, prompt-output illustrations)
  are labelled "example-derived" — they show usage, not the Zod schema, and
  must not be treated as the schema. The authoritative per-component schemas
  are the Zod objects in the package source (`packages/react-ui/src/genui-lib`
  in the repo); this inventory could not enumerate them because GitHub
  directory pages render only the README in text fetch and the jsDelivr file
  tree is JavaScript-driven.
- **Props semantics (from the fetched docs, applies to every GenUI component):**
  props are declared with a Zod object; **key order is the positional argument
  order**; a non-optional key is required (parser error `missing-required` /
  `null-required` if absent/null); `.optional()` / `.default()` keys are
  optional; extra positional args report `excess-args` and are dropped; a wrong
  optional argument falls back to its default. An `action()` prop prints as
  `action?: ActionExpression` in the prompt.
- **Library membership** below follows the current API-reference page
  (chat library root `Card`, includes `FollowUpBlock`, `ListBlock`,
  `SectionBlock`, does NOT include `Stack`; general library root `Stack`, full
  suite with `Stack`, `Tabs`, `Carousel`, `Accordion`, `Modal`) plus the
  0.17-era membership detail (only-general: `Stack`, `Modal`; only-chat:
  `FollowUpBlock`/`FollowUpItem`, `ListBlock`/`ListItem`,
  `SectionBlock`/`SectionItem`; everything else shared). Where membership is
  only 0.17-era, it is marked as such and needs re-verification against 0.18
  source.

## Counts

- **GenUI names carried over from the 0.17.0 baseline: 86** (layout 13, content
  16, data 21, forms 19, actions 3, dialogue 4, composite blocks 10).
- **Split by library (0.17-era membership, not re-confirmed for 0.18):**
  openuiLibrary-only 2 (`Stack`, `Modal`); openuiChatLibrary-only 6
  (`FollowUpBlock`, `FollowUpItem`, `ListBlock`, `ListItem`, `SectionBlock`,
  `SectionItem`); both 78. 2 + 6 + 78 = 86.
- **Confirmed in 0.18 docs:** the two libraries still exist with the same
  roots (`Stack` / `Card`); the chat library still excludes `Stack` and still
  includes `FollowUpBlock`, `ListBlock`, `SectionBlock`.
- **Not established for 0.18 (see "0.17.0 → 0.18.1 diff" below):** any component
  addition, removal, or rename between 0.17.0 and 0.18.1. The count "86" for
  0.18 is therefore the *carried-over baseline*, not a verified 0.18 count.

## 0.17.0 → 0.18.1 diff: what is established, what is not

Established (current official docs):

- Lang 1.0 runtime changes (not component changes): lone action form
  (`Button("...", @ToAssistant(...))` without `Action([...])`); custom functions
  (`defineFunction`) and custom actions (`defineAction`); `library.extend`
  (add / override / remove); stored-message format (`]]>openui:` markers);
  new error codes `unknown-function` and `no-root`; `action()` replaces
  `tagSchemaId(z.any(), "ActionExpression")` for action props; restricted
  action slots shape the prompt/schema only, the runtime does not enforce them.
- `react-ui` 0.18 requires React 19 and `react-lang` 1.x (see peer deps above).
- Docs re-stamped 2026-10-26; `react-ui` npm latest moved 0.17.0 → 0.18.1.

NOT established (do not assert in the diff):

- No component addition, removal, or rename between 0.17.0 and 0.18.1 could be
  confirmed from any fetched source. In particular, the 0.18 README category
  table omits many 0.17 GenUI names (`Stack`, `Modal`, `Form`, `SelectItem`,
  `Text`, `BoldText`, `EditableTable`, `Series`, `Slice`, `Point`,
  `Chips`/`OptionCards`, `MetricIndicator*`, composite blocks, …) — but that
  table is a simplified summary with an explicit `...`, so omission is NOT
  evidence of removal.
- Whether the 0.17-era standalone chart primitives (`HeatmapChart`,
  `FunnelChart`, `CalendarHeatmap`, `*Condensed`, Mini charts, `StackedLegend`)
  became GenUI components in 0.18 is NOT established; the 0.18 README chart
  list ends with `...` and hides the tail.
- The 0.17-era naming caveats are unresolved: composite blocks appeared in
  repo PRs under longer names (`SnippetCardBlock` / `SnippetCardItem`, …)
  while the 0.17 doc used short names; and the markdown component's casing
  differs between sources (`MarkDownRenderer` in the 0.17 doc vs
  `MarkdownRenderer` in the Flutter inventory). Neither is resolved by the
  fetched 0.18 docs, which name neither.

## Flags: deprecated / experimental / email-only

- **No GenUI component is marked deprecated or experimental in any fetched
  0.18 official page.** (Absence of a flag is not proof none exists — the
  fetched pages simply do not carry per-component flags.)
- **Email-only components are NOT in `react-ui`.** Email generation lives in
  the separate package `@openuidev/react-email` (0.4.0, per the version
  matrix); nothing fetched lists its components, and none is claimed here.
- **Removed (0.17-era, consistent with 0.18 docs):** the old chat shells
  `Shell`, `CopilotShell`, `BottomTray`, `OpenUIChat` are gone; the 0.18 README
  and API reference present `AgentInterface` as the single chat surface.
  `ToolMessageRenderer` was a deprecated compatibility wrapper for `ToolResult`
  in the 0.17 doc; its status in 0.18 was not re-verified.
- **Stale third-party guides still show `FullScreen` / `Copilot` /
  `BottomTray`** — those are pre-`AgentInterface` shells, not current API.

## Layout and structure (13)

### Stack

- Library: openuiLibrary only; it is the general library's root.
- Props: props not documented on the fetched official pages. Example-derived
  only: docs examples show `Stack([children])`; a component-group note on the
  defining-components page mentions `direction: "row"` and `wrap: true` for
  grid-like layouts. Neither is a schema.

### Tabs

- Library: both (0.17-era; 0.18 API reference lists `Tabs` in the general
  library's full suite).
- Props: props not documented on the fetched official pages.

### TabItem

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages. A
  defining-components illustration (not the built-in schema) uses a tab-item
  shape with `value`, `trigger`, and `content` fields — do not treat that
  illustration as the built-in `TabItem` schema.

### Accordion

- Library: both (0.17-era; 0.18 API reference lists `Accordion` in the general
  library's full suite).
- Props: props not documented on the fetched official pages.

### AccordionItem

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### Steps

- Library: both (0.17-era; the 0.18 README describes the chat library as a
  "chat-optimized subset with follow-ups, steps, and callouts", consistent
  with `Steps` being in the chat library too).
- Props: props not documented on the fetched official pages.

### StepsItem

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### Carousel

- Library: both (0.17-era; 0.18 API reference lists `Carousel` in the general
  library's full suite).
- Props: props not documented on the fetched official pages.

### Separator

- Library: both (0.17-era; 0.18 README lists `Separator` under Layout).
- Props: props not documented on the fetched official pages.

### Modal

- Library: openuiLibrary only (0.17-era; 0.18 API reference lists `Modal` in
  the general library's full suite and the chat library does not include it).
- Props: props not documented on the fetched official pages.

### SectionBlock

- Library: openuiChatLibrary only (confirmed in the 0.18 API reference, which
  names `SectionBlock` as chat-specific).
- Props: props not documented on the fetched official pages.

### SectionItem

- Library: openuiChatLibrary only (0.17-era; paired with `SectionBlock`).
- Props: props not documented on the fetched official pages.

### Card

- Library: both; it is the chat library's root.
- Props: props not documented on the fetched official pages. Example-derived
  only: docs examples show `Card([children])`; the 0.17-era note says the
  chat variant (`ChatCard`) supports a sources strip and `[n]` citation
  markers — not re-verified in the fetched 0.18 docs.

## Content and expression (16)

### CardHeader

- Library: both (0.17-era; 0.18 README lists `CardHeader` under Layout).
- Props: props not documented on the fetched official pages. Example-derived
  only: docs examples show `CardHeader("Q1 revenue")` and
  `CardHeader("Q1 revenue", "All segments")` — a title plus an optional
  second (subtitle) positional. Not a schema.

### TextContent

- Library: both (0.17-era; 0.18 README lists `TextContent` under Content).
- Props: props not documented on the fetched official pages. Example-derived
  only: docs examples show `TextContent("text")`,
  `TextContent("Open Tickets", "small")`, and `TextContent("...", "large-heavy")`
  — a text plus an optional size/variant string positional. Not a schema.

### Text

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### BoldText

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### MarkDownRenderer

- Library: both (0.17-era; 0.18 README lists `MarkDownRenderer` under Content).
- Props: props not documented on the fetched official pages.
- Naming caveat: casing differs across sources (`MarkDownRenderer` here and in
  the 0.17 doc vs `MarkdownRenderer` in the Flutter inventory). The fetched
  0.18 README uses `MarkDownRenderer`; trust the README spelling for the
  React side until the package source is checked.

### Callout

- Library: both (0.17-era; 0.18 README lists `Callout` under Feedback; the
  chat library is described as including "callouts").
- Props: props not documented on the fetched official pages.

### TextCallout

- Library: both (0.17-era; 0.18 README lists `TextCallout` under Feedback).
- Props: props not documented on the fetched official pages.

### Image

- Library: both (0.17-era; 0.18 README lists `Image` under Data Display).
- Props: props not documented on the fetched official pages.

### ImageBlock

- Library: both (0.17-era; 0.18 README lists `ImageBlock` under Data Display).
- Props: props not documented on the fetched official pages.

### ImageGallery

- Library: both (0.17-era; 0.18 README lists `ImageGallery` under Data Display).
- Props: props not documented on the fetched official pages.

### ImageText

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### ImageTextLarge

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### IconText

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### CodeBlock

- Library: both (0.17-era; 0.18 README lists `CodeBlock` under Data Display).
- Props: props not documented on the fetched official pages. Note: the
  defining-components `extend` example overrides `CodeBlock` in a derived
  library, confirming it is a built-in component name in 0.18, but it gives no
  schema.

### InlineHeader

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### Icon

- Library: both (0.17-era; the 0.17 doc notes `Tag.icon` references `Icon`
  rather than a string).
- Props: props not documented on the fetched official pages.

## Data display (21)

### Table

- Library: both (0.17-era; 0.18 README lists `Table` under Data Display).
- Props: props not documented on the fetched official pages. Example-derived
  only: docs examples show `Table([Col(...), Col(...)])` — a list of `Col`
  children. The API-reference page confirms the runtime behavior: a GenUI
  `Table` automatically renders `TableSkeleton` while queries load and no data
  rows exist yet.

### Col

- Library: both (0.17-era; parent-read by `Table`).
- Props: props not documented on the fetched official pages. Example-derived
  only: the functions page shows `Col("Region", regions)` and
  `Col("Sales", sales, "number")` — a label, a values array, and an optional
  third positional (`"number"`, plausibly a format/type). Not a schema.

### EditableTable

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### BarChart

- Library: both (0.17-era; 0.18 README lists `BarChart` under Data Display).
- Props: props not documented on the fetched official pages. Example-derived
  only: docs examples show `BarChart(months, [revSeries])` — categories plus
  a list of `Series`. Not a schema.

### LineChart

- Library: both (0.17-era; 0.18 README lists `LineChart` under Data Display).
- Props: props not documented on the fetched official pages.

### AreaChart

- Library: both (0.17-era; 0.18 README lists `AreaChart` under Data Display).
- Props: props not documented on the fetched official pages.

### RadarChart

- Library: both (0.17-era; 0.18 README lists `RadarChart` under Data Display).
  Also confirmed as a built-in name in 0.18 by the defining-components
  `extend` example, which removes `"RadarChart"` from a derived library.
- Props: props not documented on the fetched official pages.

### HorizontalBarChart

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### Series

- Library: both (0.17-era; parent-read by the two-dimensional charts).
- Props: props not documented on the fetched official pages. Example-derived
  only: docs examples show `Series("Revenue", [120, 145, 180])` — a label plus
  a numeric values array. Not a schema.

### PieChart

- Library: both (0.17-era; 0.18 README lists `PieChart` under Data Display).
- Props: props not documented on the fetched official pages.

### RadialChart

- Library: both (0.17-era; 0.18 README lists `RadialChart` under Data Display).
- Props: props not documented on the fetched official pages.

### SingleStackedBarChart

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.
- Naming caveat: the 0.17 doc says the standalone primitive is
  `SingleStackedBar` (= `SegmentedBar`); the GenUI name recorded in the
  baseline is `SingleStackedBarChart`. Whether 0.18 unifies or keeps both
  names is not established by the fetched docs.

### Slice

- Library: both (0.17-era; parent-read by `PieChart` / `RadialChart` /
  `SingleStackedBarChart`).
- Props: props not documented on the fetched official pages.

### ScatterChart

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### ScatterSeries

- Library: both (0.17-era; parent-read by `ScatterChart`).
- Props: props not documented on the fetched official pages.

### Point

- Library: both (0.17-era; parent-read by `ScatterSeries`).
- Props: props not documented on the fetched official pages.

### TagBlock

- Library: both (0.17-era; 0.18 README lists `TagBlock` under Data Display).
- Props: props not documented on the fetched official pages.

### Tag

- Library: both (0.17-era; 0.18 README lists `Tag` under Data Display).
- Props: props not documented on the fetched official pages. Example-derived
  only: the functions page shows `Tag(t.priority, null, "sm")` inside an
  `@Each` template — a first positional, a second positional skipped with
  `null`, and a `"sm"` size positional. Not a schema.

### EntityList

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### MetricIndicatorInline

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### MetricIndicatorWithStrikethrough

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

## Forms and input (19)

### Form

- Library: both (0.17-era; the defining-components page's group example lists
  `Form` in the Forms group).
- Props: prompt signature shown in a docs example (defining-components page,
  presented as generated prompt output, not as the Zod schema itself):

  | Prop | Type (as printed) | Required |
  | --- | --- | --- |
  | `id` | `string` | yes (no `?` in the printed signature) |
  | `buttons` | `Buttons` | yes |
  | `controls` | `FormControl[]` | yes |

  Printed form: `Form(id: string, buttons: Buttons, controls: FormControl[])`.
  A group note on the same page adds: "Form requires explicit buttons" and
  "NEVER nest Form inside Form." Treat the table as example-level: the page
  prints it as illustrative prompt output, and the Zod schema was not fetched.

### FormControl

- Library: both (0.17-era; 0.18 README lists `FormControl` under Forms).
- Props: prompt signature shown in a docs example (same page, same caveat):

  | Prop | Type (as printed) | Required |
  | --- | --- | --- |
  | `label` | `string` | yes |
  | `field` | `Input \| TextArea \| Select` | yes |

  Printed form: `FormControl(label: string, field: Input | TextArea | Select)`.
  A group note on the same page adds: "Define EACH FormControl as its own
  reference for progressive streaming."

### Label

- Library: both (0.17-era; 0.18 README lists `Label` under Forms).
- Props: props not documented on the fetched official pages.

### Input

- Library: both (0.17-era; 0.18 README lists `Input` under Forms).
- Props: props not documented on the fetched official pages. The
  defining-components page's `Input` illustration (a doc example, not the
  built-in schema) uses `name` plus an optional `rules` (tagged
  `ValidationRules`); do not treat that illustration as the built-in schema.
  The react-lang API page documents the runtime form hooks (`useStateField`,
  `useFormValidation`, `validate`, `parseRules`, `builtInValidators`) that
  form components build on, but gives no `Input` prop table.

### TextArea

- Library: both (0.17-era; 0.18 README lists `TextArea` under Forms).
- Props: props not documented on the fetched official pages.

### Select

- Library: both (0.17-era; 0.18 README lists `Select` under Forms).
- Props: props not documented on the fetched official pages.

### SelectItem

- Library: both (0.17-era; parent-read by `Select`).
- Props: props not documented on the fetched official pages.

### DatePicker

- Library: both (0.17-era; 0.18 README lists `DatePicker` under Forms).
- Props: props not documented on the fetched official pages.

### Slider

- Library: both (0.17-era; 0.18 README lists `Slider` under Forms).
- Props: props not documented on the fetched official pages.

### CheckBoxGroup

- Library: both (0.17-era; 0.18 README lists `CheckBoxGroup` under Forms).
- Props: props not documented on the fetched official pages.

### CheckBoxItem

- Library: both (0.17-era; parent-read by `CheckBoxGroup`).
- Props: props not documented on the fetched official pages.

### RadioGroup

- Library: both (0.17-era; 0.18 README lists `RadioGroup` under Forms).
- Props: props not documented on the fetched official pages.

### RadioItem

- Library: both (0.17-era; parent-read by `RadioGroup`).
- Props: props not documented on the fetched official pages.

### SwitchGroup

- Library: both (0.17-era; 0.18 README lists `SwitchGroup` under Forms).
- Props: props not documented on the fetched official pages.

### SwitchItem

- Library: both (0.17-era; parent-read by `SwitchGroup`).
- Props: props not documented on the fetched official pages.

### Chips

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### ChipItem

- Library: both (0.17-era; parent-read by `Chips`).
- Props: props not documented on the fetched official pages.

### OptionCards

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### OptionCard

- Library: both (0.17-era; parent-read by `OptionCards`).
- Props: props not documented on the fetched official pages.

## Actions and feedback (3)

### Button

- Library: both (0.17-era; 0.18 README lists `Button` under Actions).
- Props: props not documented on the fetched official pages as a schema.
  Example-derived only, from three independent docs examples that agree on the
  shape: `Button("label")`, `Button("Tell me more",
  @ToAssistant("Tell me more about this order"))`, `Button("Save",
  Action([@Run(save), @Run(orders), @Reset($note)]))`, and the
  defining-components illustration `Button(label: string, action?:
  ActionExpression)`. So the shape is a label plus an optional action prop;
  the exact prop name of the action slot in the built-in schema was not
  fetched — do not assume it is `action` without checking the package source.

### Buttons

- Library: both (0.17-era; 0.18 README lists `Buttons` under Actions; the
  `Form` prompt signature takes `buttons: Buttons`).
- Props: props not documented on the fetched official pages.

### IconButton

- Library: both (0.17-era; 0.18 README lists `IconButton` under Actions).
- Props: props not documented on the fetched official pages.

## Dialogue guidance (4)

### FollowUpBlock

- Library: openuiChatLibrary only (confirmed in the 0.18 API reference, which
  names `FollowUpBlock` as chat-specific; 0.18 README lists it under Actions).
- Props: props not documented on the fetched official pages.

### FollowUpItem

- Library: openuiChatLibrary only (0.17-era; paired with `FollowUpBlock`).
- Props: props not documented on the fetched official pages.

### ListBlock

- Library: openuiChatLibrary only (confirmed in the 0.18 API reference, which
  names `ListBlock` as chat-specific; 0.18 README lists `ListBlock` under Data
  Display).
- Props: props not documented on the fetched official pages.

### ListItem

- Library: openuiChatLibrary only (0.17-era; paired with `ListBlock`; 0.18
  README lists `ListItem` under Data Display).
- Props: props not documented on the fetched official pages.

## Composite cards (10)

Naming caveat for the whole group: the 0.17 research doc records that these
blocks appeared in repo PRs under longer names (`SnippetCardBlock` /
`SnippetCardItem`, etc.) and that the GenUI-facing names in the installed
version govern. The fetched 0.18 docs name none of the ten, so the short
`Block` / `Item` names below are the carried-over 0.17 baseline, NOT
re-verified for 0.18. Membership (both libraries) is 0.17-era.

### SnippetBlock

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### SnippetItem

- Library: both (0.17-era; parent-read by `SnippetBlock`).
- Props: props not documented on the fetched official pages.

### OverviewBlock

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### OverviewItem

- Library: both (0.17-era; parent-read by `OverviewBlock`).
- Props: props not documented on the fetched official pages.

### ContextBlock

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### ContextItem

- Library: both (0.17-era; parent-read by `ContextBlock`).
- Props: props not documented on the fetched official pages.

### CompositeBlock

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### CompositeItem

- Library: both (0.17-era; parent-read by `CompositeBlock`).
- Props: props not documented on the fetched official pages.

### VisualBlock

- Library: both (0.17-era).
- Props: props not documented on the fetched official pages.

### VisualItem

- Library: both (0.17-era; parent-read by `VisualBlock`).
- Props: props not documented on the fetched official pages.

## Standalone primitives (NOT GenUI components — hand-written JSX only)

These are exported by `@openuidev/react-ui` for hand-written pages. They are
not invocable from OpenUI Lang unless wrapped in a custom library. Listed here
because the Flutter port implemented several of them as extras, and the diff
must not mistake them for GenUI membership.

### Skeleton

- Source: API-reference page (full prop table, fetched 2026-10-28).
- Role: loading placeholder; GenUI `Table` renders `TableSkeleton` while
  queries load, and data-driven GenUI components use `Skeleton` as placeholder.

  | Prop | Type | Default |
  | --- | --- | --- |
  | `count` | `number` | `1` |
  | `height` | `string` | `"16px"` |
  | `width` | `string` | `"100%"` |
  | `borderRadius` | `string` | `undefined` (defaults to `--openui-radius-xs`) |

### TableSkeleton

- Source: API-reference page (full prop table, fetched 2026-10-28).

  | Prop | Type | Default |
  | --- | --- | --- |
  | `rows` | `number` | `5` |
  | `columns` | `number` | `4` |

### Citation / Sources / SourceFaviconImage

- 0.17-era standalone primitives for the citation/source strip on chat cards
  (0.17 doc §2.4). Not re-verified in the fetched 0.18 docs; props not
  documented on the fetched official pages.

### HeatmapChart / FunnelChart / CalendarHeatmap

- 0.17-era standalone chart primitives (0.17 doc §2.2). GenUI membership in
  0.18 NOT established (see "0.17.0 → 0.18.1 diff"). Props not documented on
  the fetched official pages.

### BarChartCondensed / LineChartCondensed / AreaChartCondensed

- 0.17-era compact chart variants (0.17 doc §2.2). GenUI membership in 0.18
  NOT established. Props not documented on the fetched official pages.

### Mini charts (MiniBarChart / MiniLineChart in the Flutter port's naming)

- 0.17-era "Mini chart series" for small embedded use (0.17 doc §2.2); exact
  0.18 export names not established. GenUI membership in 0.18 NOT established.
  Props not documented on the fetched official pages.

### StackedLegend (+ LegendStoreProvider)

- 0.17-era stacked-chart legend primitive (0.17 doc §2.2). GenUI membership
  in 0.18 NOT established. Props not documented on the fetched official pages.

### Theme (ThemeProvider / createTheme / defaultLightTheme / defaultDarkTheme / swatchTokens / useTheme / useThemeModePreference)

- 0.17-era theming layer (0.17 doc §2.5); the 0.18 README confirms
  `ThemeProvider`, `createTheme(overrides)`, `defaultLightTheme`,
  `defaultDarkTheme`, `swatchTokens` still exist, with renamed theme keys in
  the README example (`interactiveAccentDefault`, `background`,
  `textNeutralPrimary`). Not components; no GenUI membership.

## Chat surface: AgentInterface (NOT a GenUI component)

Source: API-reference page (fetched 2026-10-28). `AgentInterface` is the
package's full-page artifact chat surface; it wraps `ChatProvider`, so it
accepts the provider's `storage` + `llm` props alongside the shared UI props.
It extends `ChatProviderProps` (minus `children`) and adds:

| Prop | Type / notes | Required |
| --- | --- | --- |
| `storage` | `ChatStorage` — thread (and optional artifact) persistence; defaults to in-memory | no |
| `llm` | `ChatLLM` — `{ send({ threadId, messages, signal }), streamProtocol }` | yes |
| `artifactRenderers` | `ArtifactRendererConfig[]` | no |
| `artifactCategories` | `ArtifactCategory[]` | no |
| `artifactAutoOpen` | `boolean` | no |
| `componentLibrary` | `Library` (from `@openuidev/react-lang`) — drives auto-GenUI rendering | no |
| `onAction` | `(event: ActionEvent) => void` — actions the chat does not handle, e.g. custom actions | no |
| `components` | `AgentInterfaceComponents` — `{ AssistantMessage?, UserMessage?, ToolCallTimeline? }` overrides | no |
| `logoUrl` | `string` | no |
| `agentName` | `string` | no |
| `labels` | `AgentInterfaceLabels` | no |
| `starters` | `ConversationStarterProps[]` | no |
| `starterVariant` | `ConversationStarterVariant` | no |
| `scrollVariant` | `ScrollVariant` | no |
| `scrollOnLoad` | `boolean` | no |
| `path` / `defaultPath` | `string` | no |
| `onNavigate` | `(next: string \| undefined) => void` | no |
| `theme` | `ThemeProps` | no |
| `disableThemeProvider` | `boolean` | no |

Slots (compound static components, 0.17-era list, consistent with the 0.18
surface): `AgentInterface.Sidebar`, `.SidebarHeader`, `.SidebarFooter`,
`.MobileHeader`, `.ThreadHeader`, `.Welcome`, `.Composer`, `.Workspace`, plus
static pieces `.SidebarContent`, `.SidebarSeparator`, `.SidebarItem`,
`.ArtifactNav`, `.Route`, `.NewChatButton`, `.HistoryButton`,
`.ThemeModeToggle`, `.ThreadList`, `.Messages`, `.MessageLoading`,
`.ScrollArea`. Slot props were not documented on the fetched pages.
Tool UI: `ToolCall` (compound: `Root` / `Trigger` / `Content` / `StatusIcon` /
`StatusText` / `ToolName` / `Parameters` / `Result`, plus `DefaultToolCard`
and `TimelineToolCard`), `ToolCallTimeline`, `ToolResult`,
`defineArtifactRenderer`. The 0.18 README lists `ToolCall` and `ToolResult`
under Chat.

## Appendix A: built-in functions (part of the library contract)

Source: functions page (fetched 2026-10-28). 14 built-ins. Built-ins convert
arguments instead of validating them (e.g. `@Sum(["1", 2])` gives `3`); custom
functions validate like component props. Prompt signatures are printed for
built-ins the same way as for custom functions.

| Function | Signature / behavior (as documented) |
| --- | --- |
| `@Count(array)` | Length of array |
| `@Sum(numbers: number[]) → number` | Sum of numbers |
| `@Avg(array)` | Average |
| `@Min(array)` | Smallest value |
| `@Max(array)` | Largest value |
| `@First(array)` | First element |
| `@Last(array)` | Last element |
| `@Filter(array: any[], field: string, operator: "==" \| "!=" \| ">" \| "<" \| ">=" \| "<=" \| "contains", value: any) → any[]` | Keep items where field matches |
| `@Sort(array, field, direction?)` | Sort by field; direction `"asc"` (default) or `"desc"` |
| `@Round(number: number, decimals?: number) → number` | Round to N decimal places |
| `@Abs(number)` | Absolute value |
| `@Floor(number)` | Round down |
| `@Ceil(number)` | Round up |
| `@Each(array, "var", template)` | Render a template for every item; second argument is the loop variable name |

## Appendix B: actions (part of the library contract)

Source: specification page (fetched 2026-10-28). One action needs no wrapper;
several go in `Action([...])` and run in order. A mutation that fails stops
the rest; a custom action with any invalid argument is a no-op (no
default fallback).

| Action | Arguments |
| --- | --- |
| `@ToAssistant(message, context?)` | Send a `continue_conversation` event; `context` can be any value, reaches the host unchanged in `params.context` |
| `@OpenUrl(url)` | Send an `open_url` event |
| `@Set($var, value)` | Set a `$variable`; value evaluated when the action runs |
| `@Reset($var1, $var2)` | Restore `$variables` to declared defaults |
| `@Run(ref)` | Run a Mutation or re-fetch a Query |
| `@Name(args)` (custom) | Sends an event with `type: "Name"` and `params` |

Error codes (specification + react-lang pages): `unknown-component`,
`missing-required`, `null-required`, `type-mismatch`, `excess-args`,
`inline-reserved`, `unknown-function` (new in 1.0), `no-root` (new in 1.0),
`tool-not-found`, `tool-error`, `mcp-error`, `parse-failed`,
`parse-exception`, `runtime-error`, `render-error`.

## Top gaps and uncertainties (what this inventory could NOT establish)

1. **Per-component Zod schemas for ~80 of the 86 GenUI names.** The fetched
   official docs contain no per-component prop reference; the "built-in
   component libraries" docs link 404s; the package README table is a
   simplified summary. The schemas must be read from
   `packages/react-ui/src/genui-lib` in the repo (or the published
   `genui-lib` type definitions) by a route that can enumerate files — text
   fetch of GitHub directory pages and the jsDelivr file tree did not expose
   them. Until then, every "props not documented" line above is the honest
   state, and the Flutter diff's prop comparison for those components is
   blocked on that source, not on this inventory's completeness.
2. **0.17.0 → 0.18.1 component add/remove/rename.** No fetched source lists
   0.18's full GenUI set, and no 0.18 changelog was found. The 86-name list is
   the carried-over 0.17 baseline; treat any 0.18 delta as unknown, not zero.
   (What IS established for 0.18: Lang 1.0 runtime features, React 19 /
   react-lang 1.x peer deps, and the two libraries' roots and chat-only
   members named on the API-reference page.)
3. **Composite-block GenUI names and the markdown component's casing.**
   `SnippetBlock` vs `SnippetCardBlock` (and siblings) and `MarkDownRenderer`
   vs `MarkdownRenderer` are unresolved by the fetched 0.18 docs; the
   Flutter port's names (`SnippetBlock`, …, `MarkdownRenderer`) may or may
   not match 0.18. Also unresolved: whether `SingleStackedBarChart` (GenUI)
   vs `SingleStackedBar` (primitive) are one component or two, and whether
   the 0.17 standalone charts (Heatmap/Funnel/CalendarHeatmap, Condensed,
   Mini, StackedLegend) entered the GenUI library in 0.18.
4. **Library membership detail beyond the API-reference page's short list.**
   Only `Stack` (excluded from chat), `FollowUpBlock`, `ListBlock`,
   `SectionBlock` (chat-only) are confirmed for 0.18; the remaining
   membership split (notably `Modal` general-only and the six chat-only
   names) rests on the 0.17-era doc and needs a 0.18 source check.
5. **Deprecated / experimental flags per component.** None found in fetched
   0.18 pages, but the fetched pages carry no per-component flags at all, so
   this is "not observed", not "none exist". Email-only components live in
   `@openuidev/react-email` (0.4.0) and were not inventoried here.
