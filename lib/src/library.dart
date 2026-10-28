import 'lang.dart';

const _s = PropType.string;
const _n = PropType.number;
const _l = PropType.list;
const _b = PropType.boolean;
const _nodes = PropType.nodeList;
const _node = PropType.node;
const _any = PropType.any;
const _act = PropType.action;

/// The full library: 95 components. Names are aligned directly with
/// @openuidev/react-ui 0.18.1 (see docs/react-1.0-diff/): layout 13,
/// content 16, data 21, form 19, actions 3, dialogue 4, composite
/// cards 10 (SnippetCardBlock/SnippetCardItem and so on, plus
/// MarkDownRenderer), plus 9 extra chart components.
///
/// Props follow the official Zod schemas in @openuidev/react-ui 0.18.1
/// (see docs/react-1.0-diff/react-source-props.md) in declaration order,
/// except where a deviation is noted on the component itself. This
/// order is the contract: OpenUI Lang maps positional arguments
/// to props in this order, and `library.prompt()` prints it for the model.
/// Still pending (later batches): the Form family, the 10 card-block
/// components, EditableTable, and the general/chat library split; the
/// 9 extra chart components keep their own props (they are not React
/// GenUI names).
///
/// The canonical library constructor. Use this for all new code.
OpenUILibrary openUIStandardLibrary({String root = 'Stack', List<FunctionDef> functions = const []}) {
  return OpenUILibrary(
    root: root,
    functions: functions,
    components: [
      // ---- Layout & structure (13) ----
      const ComponentDef('Stack', 'Stack container, the generic root. direction: row/column; gap: none/xs/s/m/l/xl/2xl; align: start/center/end/stretch/baseline; justify: start/center/end/between/around/evenly; wrap: wrap children.', [
        PropDef('children', _nodes, required: true),
        PropDef('direction', _s),
        PropDef('gap', _s),
        PropDef('align', _s),
        PropDef('justify', _s),
        PropDef('wrap', _b),
      ]),
      const ComponentDef('Card', 'Card container, the chat root. variant: card/sunk/clear; plus the Stack flex props. (The chat Card sources variant is not implemented.)', [
        PropDef('children', _nodes, required: true),
        PropDef('variant', _s),
        PropDef('direction', _s),
        PropDef('gap', _s),
        PropDef('align', _s),
        PropDef('justify', _s),
        PropDef('wrap', _b),
      ]),
      const ComponentDef('Tabs', 'Tabbed container; pass TabItem nodes as a list.', [
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('TabItem', 'One tab: value, trigger label, content nodes.', [
        PropDef('value', _s, required: true),
        PropDef('trigger', _s, required: true),
        PropDef('content', _nodes, required: true),
      ]),
      const ComponentDef('Accordion', 'Collapsible panels; pass AccordionItem nodes.', [
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('AccordionItem', 'One collapsible panel: value, trigger label, content nodes.', [
        PropDef('value', _s, required: true),
        PropDef('trigger', _s, required: true),
        PropDef('content', _nodes, required: true),
      ]),
      const ComponentDef('Steps', 'Step list; pass StepsItem nodes.', [
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('StepsItem', 'One step: title and details text.', [
        PropDef('title', _s, required: true),
        PropDef('details', _s, required: true),
      ]),
      const ComponentDef('Carousel', 'Swipeable pages; children is a list of slides, each slide a list of nodes. variant: card/sunk.', [
        PropDef('children', _l, required: true),
        PropDef('variant', _s),
      ]),
      const ComponentDef('Separator', 'Divider line between blocks. orientation: horizontal/vertical; decorative is accepted but has no visible effect.', [
        PropDef('orientation', _s),
        PropDef('decorative', _b),
      ]),
      const ComponentDef('Modal', 'Dialog-style container; renders as a real AlertDialog. open: false renders nothing; size: sm/md/lg dialog width.', [
        PropDef('title', _s, required: true),
        PropDef('open', _b),
        PropDef('children', _nodes, required: true),
        PropDef('size', _s),
      ]),
      const ComponentDef('SectionBlock', 'Chat grouping block; pass SectionItem nodes.', [
        PropDef('title', _s),
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('SectionItem', 'One grouped item: label and its content nodes.', [
        PropDef('label', _s, required: true),
        PropDef('children', _nodes),
      ]),
      // ---- Content & expression (16) ----
      const ComponentDef('CardHeader', 'Card title and subtitle; both optional.', [
        PropDef('title', _s),
        PropDef('subtitle', _s),
      ]),
      const ComponentDef('TextContent', 'Body text. size: small/default/large/small-heavy/large-heavy.', [
        PropDef('text', _s, required: true),
        PropDef('size', _s),
      ]),
      // DOCUMENTED DEVIATION: React schema order is
      // variant/value/subtext/subtextVariant/size, but a one-arg
      // positional call would then bind to variant, not the text.
      // This library puts value first so Text("...") works; the
      // remaining props follow schema order.
      const ComponentDef('Text', 'Plain inline text. variant: text/number; size: xs/sm/md/lg.', [
        PropDef('value', _s, required: true),
        PropDef('variant', _s, defaultValue: 'text'),
        PropDef('subtext', _s),
        PropDef('subtextVariant', _s, defaultValue: 'text'),
        PropDef('size', _s, defaultValue: 'sm'),
      ]),
      const ComponentDef('BoldText', 'Bold inline text. Same props as Text, value first (see Text note).', [
        PropDef('value', _s, required: true),
        PropDef('variant', _s, defaultValue: 'text'),
        PropDef('subtext', _s),
        PropDef('subtextVariant', _s, defaultValue: 'text'),
        PropDef('size', _s, defaultValue: 'sm'),
      ]),
      const ComponentDef('MarkDownRenderer', 'Markdown text rendered by flutter_markdown_plus (full Markdown). variant: clear/card/sunk.', [
        PropDef('textMarkdown', _s, required: true),
        PropDef('variant', _s),
      ]),
      const ComponentDef('Callout', 'Callout block. variant: info/warning/error/success/neutral; visible: false renders nothing.', [
        PropDef('variant', _s, required: true),
        PropDef('title', _s, required: true),
        PropDef('description', _s, required: true),
        PropDef('visible', _b),
      ]),
      const ComponentDef('TextCallout', 'Text callout block; all props optional. variant: neutral/info/warning/success/danger.', [
        PropDef('variant', _s),
        PropDef('title', _s),
        PropDef('description', _s),
      ]),
      const ComponentDef('Image', 'Single image from a network URL. alt is required; src absent renders the alt text.', [
        PropDef('alt', _s, required: true),
        PropDef('src', _s),
      ]),
      const ComponentDef('ImageBlock', 'Image with an optional alt line.', [
        PropDef('src', _s, required: true),
        PropDef('alt', _s),
      ]),
      const ComponentDef('ImageGallery', 'Horizontal gallery; images is a list of {src, alt?, details?} objects (plain URL strings are also accepted).', [
        PropDef('images', _l, required: true),
      ]),
      const ComponentDef('ImageText', 'Small image beside a title and optional subtitle. bold: title in bold; layout: horizontal/vertical; imageSize: image side in logical pixels.', [
        PropDef('src', _s, required: true),
        PropDef('alt', _s),
        PropDef('title', _s, required: true),
        PropDef('subtitle', _s),
        PropDef('bold', _b, defaultValue: false),
        PropDef('layout', _s, defaultValue: 'horizontal'),
        PropDef('imageSize', _n),
      ]),
      const ComponentDef('ImageTextLarge', 'Large image above a title and optional subtitle.', [
        PropDef('src', _s, required: true),
        PropDef('alt', _s),
        PropDef('title', _s, required: true),
        PropDef('subtitle', _s),
        PropDef('bold', _b, defaultValue: false),
      ]),
      const ComponentDef('IconText', 'Icon plus title and optional subtitle. icon is a string name like "search" (React takes an Icon ref; this port keeps the string name). iconVariant: neutral/info/success/warning/danger/inverted/filled/soft; iconSize: xs/s/m/l/xl/sm/md/lg; layout: horizontal/vertical.', [
        PropDef('icon', _s, required: true),
        PropDef('iconVariant', _s, defaultValue: 'neutral'),
        PropDef('iconSize', _s, defaultValue: 'm'),
        PropDef('title', _s, required: true),
        PropDef('subtitle', _s),
        PropDef('bold', _b, defaultValue: false),
        PropDef('layout', _s, defaultValue: 'horizontal'),
      ]),
      const ComponentDef('CodeBlock', 'Code block, plain text (no highlighting). language first, then codeString.', [
        PropDef('language', _s, required: true),
        PropDef('codeString', _s, required: true),
      ]),
      const ComponentDef('InlineHeader', 'Inline heading with an optional description.', [
        PropDef('heading', _s, required: true),
        PropDef('description', _s),
      ]),
      const ComponentDef('Icon', 'Icon by name like "search". category is accepted but has no visible effect in this port.', [
        PropDef('name', _s, required: true),
        PropDef('category', _s),
      ]),
      // ---- Data display (21) ----
      const ComponentDef('Table', 'Columnar table; pass Col nodes as a list.', [
        PropDef('columns', _nodes, required: true),
      ]),
      const ComponentDef('Col', 'One table column: label, cell data, optional type (string/number/action; accepted but has no visible effect in this port).', [
        PropDef('label', _s, required: true),
        PropDef('data', _l, required: true),
        PropDef('type', _s),
      ]),
      const ComponentDef('EditableTable', 'Editable table. Column objects: {type: text/number/date-single/select/url, key?, header?, width?, options? [{value, label}]}. Row objects: {id, values}. Cell edits write to form state under "<name>:<rowId>:<columnKey>" (statement id when name is empty); "Save Changes" writes the full edited rows under `name` (skipped when name is empty).', [
        PropDef('name', _s, defaultValue: ''),
        PropDef('columns', _l, defaultValue: const []),
        PropDef('data', _l, defaultValue: const []),
      ]),
      const ComponentDef('BarChart', 'Bar chart: labels plus Series nodes. variant: grouped/stacked.', [
        PropDef('labels', _l, required: true),
        PropDef('series', _nodes, required: true),
        PropDef('variant', _s),
        PropDef('xLabel', _s),
        PropDef('yLabel', _s),
        PropDef('height', _n),
      ]),
      const ComponentDef('LineChart', 'Line chart: labels plus Series nodes. variant: linear/natural/step.', [
        PropDef('labels', _l, required: true),
        PropDef('series', _nodes, required: true),
        PropDef('variant', _s),
        PropDef('xLabel', _s),
        PropDef('yLabel', _s),
        PropDef('height', _n),
      ]),
      const ComponentDef('AreaChart', 'Area chart: labels plus Series nodes. variant: linear/natural/step.', [
        PropDef('labels', _l, required: true),
        PropDef('series', _nodes, required: true),
        PropDef('variant', _s),
        PropDef('xLabel', _s),
        PropDef('yLabel', _s),
        PropDef('height', _n),
      ]),
      const ComponentDef('RadarChart', 'Radar chart: labels plus Series nodes.', [
        PropDef('labels', _l, required: true),
        PropDef('series', _nodes, required: true),
      ]),
      const ComponentDef('HorizontalBarChart', 'Horizontal bar chart: labels plus Series nodes. variant: grouped/stacked.', [
        PropDef('labels', _l, required: true),
        PropDef('series', _nodes, required: true),
        PropDef('variant', _s),
        PropDef('xLabel', _s),
        PropDef('yLabel', _s),
      ]),
      const ComponentDef('Series', 'One chart series: category and numeric values.', [
        PropDef('category', _s, required: true),
        PropDef('values', _l, required: true),
      ]),
      const ComponentDef('PieChart', 'Pie chart: labels plus values arrays. variant: pie/donut; appearance: circular/semiCircular.', [
        PropDef('labels', _l, required: true),
        PropDef('values', _l, required: true),
        PropDef('variant', _s),
        PropDef('appearance', _s),
      ]),
      const ComponentDef('RadialChart', 'Radial chart: labels plus values arrays.', [
        PropDef('labels', _l, required: true),
        PropDef('values', _l, required: true),
      ]),
      const ComponentDef('SingleStackedBarChart', 'One segmented bar: labels plus values arrays.', [
        PropDef('labels', _l, required: true),
        PropDef('values', _l, required: true),
      ]),
      const ComponentDef('Slice', 'One pie/radial/stacked slice: category and numeric value. A virtual component: charts now take labels/values arrays, so Slice is only meaningful as data, not as a rendered node.', [
        PropDef('category', _s, required: true),
        PropDef('value', _n, required: true),
      ]),
      const ComponentDef('ScatterChart', 'Scatter chart: datasets of ScatterSeries nodes.', [
        PropDef('datasets', _nodes, required: true),
        PropDef('xLabel', _s),
        PropDef('yLabel', _s),
      ]),
      const ComponentDef('ScatterSeries', 'One scatter series: name and Point nodes.', [
        PropDef('name', _s, required: true),
        PropDef('points', _nodes, required: true),
      ]),
      const ComponentDef('Point', 'One scatter point: x and y numbers, optional z (accepted but not rendered in this 2D port).', [
        PropDef('x', _n, required: true),
        PropDef('y', _n, required: true),
        PropDef('z', _n),
      ]),
      // ---- Extra charts (Task 6; fl_chart except Heatmap/Funnel/
      // CalendarHeatmap, which have no fl_chart equivalent) ----
      const ComponentDef('HeatmapChart', 'Heatmap: categories plus Series nodes.', [
        PropDef('categories', _l, required: true),
        PropDef('series', _nodes, required: true),
      ]),
      const ComponentDef('FunnelChart', 'Funnel; pass Slice nodes.', [
        PropDef('slices', _nodes, required: true),
      ]),
      const ComponentDef('CalendarHeatmap', 'Calendar heatmap; values are {date, value} maps.', [
        PropDef('values', _l, required: true),
      ]),
      const ComponentDef('MiniBarChart', 'Mini bar chart; values are numbers.', [
        PropDef('values', _l, required: true),
      ]),
      const ComponentDef('MiniLineChart', 'Mini line chart; values are numbers.', [
        PropDef('values', _l, required: true),
      ]),
      const ComponentDef('StackedLegend', 'Legend swatches; pass Series nodes.', [
        PropDef('series', _nodes, required: true),
      ]),
      const ComponentDef('BarChartCondensed', 'Condensed bar chart: categories plus Series nodes.', [
        PropDef('categories', _l, required: true),
        PropDef('series', _nodes, required: true),
      ]),
      const ComponentDef('LineChartCondensed', 'Condensed line chart: categories plus Series nodes.', [
        PropDef('categories', _l, required: true),
        PropDef('series', _nodes, required: true),
      ]),
      const ComponentDef('AreaChartCondensed', 'Condensed area chart: categories plus Series nodes.', [
        PropDef('categories', _l, required: true),
        PropDef('series', _nodes, required: true),
      ]),
      const ComponentDef('TagBlock', 'Tag list; tags is a list of strings. size: sm/md/lg.', [
        PropDef('tags', _l, required: true),
        PropDef('size', _s),
      ]),
      const ComponentDef('Tag', 'One tag chip. icon is an optional icon name string (React takes an Icon ref; this port keeps the string name). size: sm/md/lg; variant: neutral/info/success/warning/danger.', [
        PropDef('text', _s, required: true),
        PropDef('icon', _s),
        PropDef('size', _s),
        PropDef('variant', _s),
      ]),
      const ComponentDef('EntityList', 'Entity list; rows is a list of {left, right, rightVariant?} objects. size: small/default; header/footer are row objects.', [
        PropDef('rows', _l, required: true),
        PropDef('size', _s, defaultValue: 'default'),
        PropDef('header', _any),
        PropDef('footer', _any),
      ]),
      const ComponentDef('MetricIndicatorInline', 'Inline metric: value, optional subtext and trend {direction: up/down, value}.', [
        PropDef('value', _any, required: true),
        PropDef('subtext', _s),
        PropDef('trend', _any),
      ]),
      const ComponentDef('MetricIndicatorWithStrikethrough', 'Metric with struck-through previous value, optional subtext and trend.', [
        PropDef('value', _any, required: true),
        PropDef('subtext', _s),
        PropDef('previousValue', _s),
        PropDef('trend', _any),
      ]),
      // ---- Form & input (19) ----
      // Props follow the @openuidev/react-ui 0.18.1 Zod schemas in
      // declaration order (see docs/react-1.0-diff/react-source-props.md
      // §2, "Forms"). Form state is keyed by each input's `name` prop
      // (the old `bind` prop is gone). `rules` is accepted and stored
      // on every input; enforcement is out of scope except the
      // required marker on FormControl labels (see renderer). The
      // mapper does not enforce FormControl's input union: any node is
      // accepted as `input`. SwitchGroup is deliberately NOT a
      // FormControl input in React's schema and stays standalone here.
      const ComponentDef('Form', 'Form container: name, Buttons node, FormControl fields.', [
        PropDef('name', _s, required: true),
        PropDef('buttons', _node, required: true),
        PropDef('fields', _nodes, defaultValue: const []),
      ]),
      const ComponentDef('FormControl', 'Field wrapper: label, a single input node, optional hint.', [
        PropDef('label', _s, required: true),
        PropDef('input', _node, required: true),
        PropDef('hint', _s),
      ]),
      const ComponentDef('Label', 'Field label text.', [
        PropDef('text', _s, required: true),
      ]),
      const ComponentDef('Input', 'Single-line text input; state key is name. type: text/email/password/number/url.', [
        PropDef('name', _s, required: true),
        PropDef('placeholder', _s),
        PropDef('type', _s),
        PropDef('rules', _any),
        PropDef('value', _any),
      ]),
      const ComponentDef('TextArea', 'Multi-line text input; state key is name.', [
        PropDef('name', _s, required: true),
        PropDef('placeholder', _s),
        PropDef('rows', _n),
        PropDef('rules', _any),
        PropDef('value', _any),
      ]),
      const ComponentDef('Select', 'Dropdown; items are SelectItem nodes, state key is name. size: small/medium/large.', [
        PropDef('name', _s, required: true),
        PropDef('items', _nodes, required: true),
        PropDef('placeholder', _s),
        PropDef('rules', _any),
        PropDef('value', _any),
        PropDef('size', _s),
      ]),
      const ComponentDef('SelectItem', 'One dropdown option: value first, then label.', [
        PropDef('value', _s, required: true),
        PropDef('label', _s, required: true),
      ]),
      const ComponentDef('DatePicker', 'Date picker; state key is name. mode range is accepted but renders as the single-date picker (documented deviation, see renderer).', [
        PropDef('name', _s, required: true),
        PropDef('mode', _s),
        PropDef('rules', _any),
        PropDef('value', _any),
      ]),
      const ComponentDef('Slider', 'Slider; state key is name, value is an array of numbers (single-thumb use takes the first element). variant/min/max are required with no defaults.', [
        PropDef('name', _s, required: true),
        PropDef('variant', _s, required: true),
        PropDef('min', _n, required: true),
        PropDef('max', _n, required: true),
        PropDef('step', _n),
        PropDef('defaultValue', _any),
        PropDef('label', _s),
        PropDef('rules', _any),
        PropDef('value', _any),
      ]),
      const ComponentDef('CheckBoxGroup', 'Multi-select group; state is a record of item name to boolean, keyed by name.', [
        PropDef('name', _s, required: true),
        PropDef('items', _nodes, required: true),
        PropDef('rules', _any),
        PropDef('value', _any),
      ]),
      const ComponentDef('CheckBoxItem', 'One checkbox option: label, description, state name, optional defaultChecked.', [
        PropDef('label', _s, required: true),
        PropDef('description', _s, required: true),
        PropDef('name', _s, required: true),
        PropDef('defaultChecked', _b),
      ]),
      const ComponentDef('RadioGroup', 'Single-select group; state is the selected item value string, keyed by name.', [
        PropDef('name', _s, required: true),
        PropDef('items', _nodes, required: true),
        PropDef('defaultValue', _s),
        PropDef('rules', _any),
        PropDef('value', _any),
      ]),
      const ComponentDef('RadioItem', 'One radio option: label, description, value.', [
        PropDef('label', _s, required: true),
        PropDef('description', _s, required: true),
        PropDef('value', _s, required: true),
      ]),
      const ComponentDef('SwitchGroup', 'Switch group (standalone: NOT a FormControl input in React\'s schema); state is a record of item name to boolean, keyed by name. variant: clear/card/sunk.', [
        PropDef('name', _s, required: true),
        PropDef('items', _nodes, required: true),
        PropDef('variant', _s),
        PropDef('value', _any),
      ]),
      const ComponentDef('SwitchItem', 'One switch option: state name required, label/description optional, optional defaultChecked.', [
        PropDef('label', _s),
        PropDef('description', _s),
        PropDef('name', _s, required: true),
        PropDef('defaultChecked', _b),
      ]),
      const ComponentDef('Chips', 'Quick-choice chips; state key is name. type: single/multiple (default multiple).', [
        PropDef('name', _s, required: true),
        PropDef('type', _s, defaultValue: 'multiple'),
        PropDef('items', _nodes, defaultValue: const []),
        PropDef('rules', _any),
        PropDef('defaultValue', _any),
      ]),
      const ComponentDef('ChipItem', 'One chip option: value first, then label; icon is a string name (React takes an Icon ref; this port keeps the string name).', [
        PropDef('value', _s, required: true),
        PropDef('label', _s, required: true),
        PropDef('icon', _s),
        PropDef('disabled', _b),
      ]),
      const ComponentDef('OptionCards', 'Selectable cards; state key is name. type: single/multiple (default single).', [
        PropDef('name', _s, required: true),
        PropDef('type', _s, defaultValue: 'single'),
        PropDef('items', _nodes, defaultValue: const []),
        PropDef('rules', _any),
        PropDef('defaultValue', _any),
      ]),
      const ComponentDef('OptionCard', 'One selectable card: value first, then title; topContent is an Icon or Image node ref.', [
        PropDef('value', _s, required: true),
        PropDef('title', _s, required: true),
        PropDef('subtitle', _s),
        PropDef('topContent', _node),
        PropDef('disabled', _b),
      ]),
      // ---- Actions & feedback (3) ----
      const ComponentDef('Button', 'Button with an optional action. variant: primary/secondary/tertiary; type: normal/destructive; size: extra-small/small/medium/large.', [
        PropDef('label', _s, required: true),
        PropDef('action', _act),
        PropDef('variant', _s),
        PropDef('type', _s),
        PropDef('size', _s),
      ]),
      const ComponentDef('Buttons', 'Button group; pass Button nodes. direction: row/column.', [
        PropDef('buttons', _nodes, required: true),
        PropDef('direction', _s),
      ]),
      const ComponentDef('IconButton', 'Icon button. name is used as the tooltip; icon is a string name like "search" (React takes an Icon ref; this port keeps the string name). variant: primary/secondary/tertiary; size: extra-small/small/medium/large; shape: square/circle.', [
        PropDef('name', _s, required: true),
        PropDef('icon', _s, required: true),
        PropDef('action', _act),
        PropDef('variant', _s),
        PropDef('size', _s),
        PropDef('shape', _s),
      ]),
      // ---- Dialogue guidance (4) ----
      const ComponentDef('FollowUpBlock', 'Follow-up suggestions; pass FollowUpItem nodes.', [
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('FollowUpItem', 'One follow-up: tapping sends it as the next question.', [
        PropDef('text', _s, required: true),
      ]),
      const ComponentDef('ListBlock', 'List block; pass ListItem nodes. variant: number/image; size: default/small.', [
        PropDef('items', _nodes, required: true),
        PropDef('variant', _s),
        PropDef('size', _s),
      ]),
      const ComponentDef('ListItem', 'One list item: title, optional subtitle, image {src, alt}, actionLabel and action.', [
        PropDef('title', _s, required: true),
        PropDef('subtitle', _s),
        PropDef('image', _any),
        PropDef('actionLabel', _s),
        PropDef('action', _act),
      ]),
      // ---- Composite cards (10) ----
      // Props follow the @openuidev/react-ui 0.18.1 Zod schemas in
      // declaration order (see docs/react-1.0-diff/react-source-props.md
      // §2, "Card blocks"). All five blocks share items/layout/
      // responsive/action/gap and have NO title prop. React's
      // items `.min(2)` constraint is NOT enforced here: no min-length
      // machinery exists in the mapper (documented deviation).
      // `layout` is grid by default; SnippetCardBlock is grid-only in
      // React, so a carousel layout on it falls back to grid in the
      // renderer. `responsive` is accepted but has no visible effect.
      const ComponentDef('SnippetCardBlock', 'Snippet card block; pass SnippetCardItem nodes.', [
        PropDef('items', _nodes, required: true),
        PropDef('layout', _s, defaultValue: 'grid'),
        PropDef('responsive', _b, defaultValue: true),
        PropDef('action', _act),
        PropDef('gap', _any),
      ]),
      const ComponentDef('SnippetCardItem', 'Snippet item: lhs node required, rhs node optional.', [
        PropDef('id', _s),
        PropDef('lhs', _node, required: true),
        PropDef('rhs', _node),
      ]),
      const ComponentDef('OverviewCardBlock', 'Overview card block; pass OverviewCardItem nodes.', [
        PropDef('items', _nodes, required: true),
        PropDef('layout', _s, defaultValue: 'grid'),
        PropDef('responsive', _b, defaultValue: true),
        PropDef('action', _act),
        PropDef('gap', _any),
      ]),
      const ComponentDef('OverviewCardItem', 'Overview item: top node required, bottom MetricIndicatorInline optional.', [
        PropDef('id', _s),
        PropDef('top', _node, required: true),
        PropDef('bottom', _node),
      ]),
      const ComponentDef('ContextCardBlock', 'Context card block; pass ContextCardItem nodes.', [
        PropDef('items', _nodes, required: true),
        PropDef('layout', _s, defaultValue: 'grid'),
        PropDef('responsive', _b, defaultValue: true),
        PropDef('action', _act),
        PropDef('gap', _any),
      ]),
      const ComponentDef('ContextCardItem', 'Context item: title is a string or a Tag node; gray bg or bg image optional.', [
        PropDef('id', _s),
        PropDef('title', _any, required: true),
        PropDef('body', _s),
        PropDef('bgColor', _s),
        PropDef('bgImageSrc', _s),
        PropDef('bgImageAlt', _s),
      ]),
      const ComponentDef('CompositeCardBlock', 'Composite card block; pass CompositeCardItem nodes.', [
        PropDef('items', _nodes, required: true),
        PropDef('layout', _s, defaultValue: 'grid'),
        PropDef('responsive', _b, defaultValue: true),
        PropDef('action', _act),
        PropDef('gap', _any),
      ]),
      const ComponentDef('CompositeCardItem', 'Composite item: optional header node, body node list, footer {price, button}.', [
        PropDef('id', _s),
        PropDef('header', _node),
        PropDef('body', _nodes, defaultValue: const []),
        PropDef('footer', _any),
      ]),
      const ComponentDef('VisualCardBlock', 'Visual card block; pass VisualCardItem nodes.', [
        PropDef('items', _nodes, required: true),
        PropDef('layout', _s, defaultValue: 'grid'),
        PropDef('responsive', _b, defaultValue: true),
        PropDef('action', _act),
        PropDef('gap', _any),
      ]),
      const ComponentDef('VisualCardItem', 'Visual item: BoldText body required, optional Tag and bg image.', [
        PropDef('body', _node, required: true),
        PropDef('id', _s),
        PropDef('bgImageSrc', _s),
        PropDef('tag', _node),
        PropDef('bgImageAlt', _s),
      ]),
    ],
  );
}

/// Deprecated alias for [openUIStandardLibrary], kept for compatibility.
/// It returns the full library, not just the original 25-component MVP.
@Deprecated('Use openUIStandardLibrary() instead.')
OpenUILibrary openUIMvpLibrary({String root = 'Stack', List<FunctionDef> functions = const []}) {
  return openUIStandardLibrary(root: root, functions: functions);
}
