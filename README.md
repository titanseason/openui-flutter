# openui_lang

[English](./README.md) | [中文](./README.zh-CN.md)

A pure-Dart Flutter renderer for OpenUI Lang 1.0 and the 82-component
general GenUI library, aligned with `@openuidev/react-ui` 0.18.1. It
parses Lang programs (including streamed, partial input) into an
element tree and renders it with Flutter widgets. Charts are fully
self-drawn; the only third-party dependency is `flutter_markdown_plus`
for Markdown.

> Status: not published on pub.dev yet. The package name is
> `openui_lang`, the version is 1.0.0, and the repository/homepage
> URLs in `pubspec.yaml` are still `.invalid` placeholders. Until the
> first publish, use a path dependency on a local checkout:
>
> ```yaml
> dependencies:
>   openui_lang:
>     path: ../openui-flutter
> ```

## Quick start

Response mode — one complete program:

```dart
import 'package:openui_lang/openui_lang.dart';

OpenUIRenderer(
  library: openUIStandardLibrary(),
  response: '''
root = Stack([title, chart])
title = CardHeader("Q1 Revenue", "All business lines")
chart = BarChart(["Jan", "Feb", "Mar"], [rev])
rev = Series("Revenue", [120, 145, 180])
''',
)
```

Controller mode — streamed input, form state, and tools:

```dart
final controller = OpenUIController(
  library: openUIStandardLibrary(),
  toolProvider: (tool, params) async => fetchFromBackend(tool, params),
);
controller.push(chunk); // call per streamed chunk
controller.finish();    // renders the final program

OpenUIRenderer(library: controller.library, controller: controller)
```

The system prompt for the model comes from the library itself:
`openUIStandardLibrary().prompt()` prints every component, its props
in order, and its description, so the model only uses components
that exist.

## What is implemented

- **Lang 1.0 parser and evaluator.** Statements are `name = Expr`
  assignments. Expressions cover literals, references, `$variables`,
  field access, indexing, list/object literals, calls, `@builtin`
  functions, actions, ternary, binary/unary operators, and
  `Query`/`Mutation` requests. Forward references resolve, and
  errors carry codes (`unknown-component`, `type-mismatch`, …).
- **Streaming and incremental parsing.** `StreamingParser`
  auto-closes an incomplete trailing line so partial input renders
  immediately; the renderer reuses an incremental parser so a
  streamed append does not re-parse the whole program twice per
  chunk. Form edits still re-parse fully (memoized rendering only
  pays off for streaming appends and host rebuilds).
- **82 components, one library.** `openUIStandardLibrary()` has
  root `Stack`. There is no chat library in this port.
- **Query and Mutation.** `Query`/`Mutation` run through the host's
  `toolProvider`, with loading, error, and `@Run` retry views.
  Host-defined tools plug in through `defineFunction`, and
  `OpenUILibrary.extend` registers custom components.
- **Forms.** `Form`/`FormControl` state flows back through
  `onStateUpdate` (response mode) or `controller.formState`.
- **Theming.** See below.

## Components (82)

- Layout (11): Stack, Card, Tabs, TabItem, Accordion, AccordionItem,
  Steps, StepsItem, Carousel, Separator, Modal.
- Content (16): CardHeader, TextContent, Text, BoldText,
  MarkDownRenderer, Callout, TextCallout, Image, ImageBlock,
  ImageGallery, ImageText, ImageTextLarge, IconText, CodeBlock,
  InlineHeader, Icon.
- Data (21): Table, Col, EditableTable, BarChart, LineChart,
  AreaChart, RadarChart, HorizontalBarChart, Series, PieChart,
  RadialChart, SingleStackedBarChart, Slice, ScatterChart,
  ScatterSeries, Point, TagBlock, Tag, EntityList,
  MetricIndicatorInline, MetricIndicatorWithStrikethrough.
- Forms (19): Form, FormControl, Label, Input, TextArea, Select,
  SelectItem, DatePicker, Slider, CheckBoxGroup, CheckBoxItem,
  RadioGroup, RadioItem, SwitchGroup, SwitchItem, Chips, ChipItem,
  OptionCards, OptionCard.
- Actions (3): Button, Buttons, IconButton.
- Lists (2): ListBlock, ListItem.
- Composite cards (10): SnippetCardBlock/SnippetCardItem,
  OverviewCardBlock/OverviewCardItem, ContextCardBlock/ContextCardItem,
  CompositeCardBlock/CompositeCardItem, VisualCardBlock/VisualCardItem.

Built-in functions (called with `@`): Count, Sum, Avg, Min, Max,
First, Last, Filter, Sort, Round, Abs, Floor, Ceil, Each. Built-in
actions: ToAssistant, OpenUrl, Set, Reset, Run.

## Theming

```dart
// Built-ins:
OpenUIThemeData.light();
OpenUIThemeData.dark();

// Custom:
OpenUIThemeData(
  colors: const OpenUIColorScheme(
    primary: Colors.blue,
    surface: Colors.white,
    onSurface: Colors.black87,
    // textMuted, border, grid, success, warning, danger, info
    // default to the light values when omitted.
  ),
  chartPalette: const [Colors.blue, Colors.green, Colors.orange],
)
```

`OpenUIColorScheme` is semantic: `primary` / `surface` /
`onSurface`, plus `textMuted` (secondary text, chart axis labels),
`border` (chart boxes, axis lines, tooltip borders), `grid` (chart
gridlines and tracks), and `success` / `warning` / `danger` / `info`
(Callout variants). Charts read their chrome from the theme through
a `ChartColors` bundle; the series palette stays separate
(`chartPalette`). `cardRadius` and the `skeletonBuilder` /
`errorBuilder` injection points live on `OpenUIThemeData`.

## Charts

Eight types, all drawn with `CustomPainter` (no chart package):
Bar, Line, Area, HorizontalBar, Pie, Radial, SingleStackedBar,
Scatter. Behavior follows React: hover tooltips (mouse hover and
touch drag; a stationary tap shows nothing), legend click to hide a
series or slice (pie re-normalizes, radial rings keep their radii,
scales are computed over all series so toggling never rescales),
zero-anchored nice domains with negatives, and stacked bars as a
horizontal track.

Bar/Line/Area accept three layout props (positional, after
`height`): `density` (`compact` 48 / `default` 72 / `spacious` 96px
slots, scroll mode only), `condensed` (fit mode: all categories
share the container width, no scrolling, labels thinned and
truncated), and `tickVariant` (`singleLine` / `multiLine` /
`angled`; angled is condensed-only and rotates labels −45°).
Axis ticks use React's number format (1.0K at 1000, M/B/T above);
tooltips use grouped numbers below 100000 and K/M/B/T above.

`onTap` exists on every chart widget, but only for hosts that
construct widgets directly in Dart: Lang text cannot carry
callbacks, so Lang-driven charts are view-only.

## Architecture

```
lib/src/
  core/     Lang, library, registry (language + registration)
  runtime/  controller, renderer, theme (host-facing runtime)
  widgets/  primitives, extra widgets (shared widget implementations)
  charts/   chart widgets + painters (one file per chart type)
```

```
Lang text (streamed)
  -> StreamingParser (splits lines; autocloser finishes a partial tail)
  -> Parser + evaluator (statements, expressions, forward refs,
     $variables, actions, Query/Mutation, error codes)
  -> ElementNode tree (Flutter-independent IR)
  -> OpenUIRenderer (maps nodes to Flutter widgets;
     Query/Mutation run through toolProvider)
```

The parser/evaluator itself uses no Flutter API, but `core/lang.dart`
imports `core/registry.dart` (which carries widget builders), so the
language core cannot currently be imported by a pure-Dart package.
That coupling is a known trade-off, not an oversight.

## Differences from React

- **Default palette.** With no palette given, this port uses
  blue/green/orange/purple/teal/red; React's no-palette fallback is
  a single-hue blue ramp (OCEAN). Pass `chartPalette` to match.
- **No entrance animations.** React's are off by default as well.
- **onClick is direct-widget-only**, as described above.
- **Markdown** comes from `flutter_markdown_plus`;
  **CodeBlock is plain text** (no syntax highlighting dependency).
- **No pixel-level parity check against React rendering exists.**
  Goldens compare Flutter against itself, and the test font is
  Ahem (all text renders as blocks), so font metrics, sizes, and
  CJK line-breaking are unverified against React.
- **No chat library.** React ships a general library and a chat
  library; this port implements the general one only.

## Development

```sh
flutter test        # main package suite
flutter analyze     # main package + example
cd example && flutter test
```

Goldens live in `test/goldens/` and `test/charts/goldens/`.
Regenerate with `flutter test --update-goldens`, then inspect the
new images before committing: a regenerated golden is a claim, not
a pass. The `example/` app has four screens (rich answer, business
dashboard, form + Query, theme & custom components).

`CHANGELOG.md` records each change, including breaking ones.

## License

Licensed under the Apache License, Version 2.0. See
[LICENSE](./LICENSE).
