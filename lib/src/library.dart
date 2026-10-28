import 'lang.dart';

const _s = PropType.string;
const _n = PropType.number;
const _l = PropType.list;
const _nodes = PropType.nodeList;
const _any = PropType.any;
const _act = PropType.action;

/// The full 86-component library (GenUI names from @openuidev/react-ui
/// 0.17.0, de-duplicated by name: layout 13, content 16, data 21,
/// form 19, actions 3, dialogue 4, composite cards 10).
///
/// Props are an MVP subset, not a 1:1 copy of the official Zod schemas:
/// one representative prop per intent, in positional-argument order.
/// This order is the contract: OpenUI Lang maps positional arguments
/// to props in this order, and `library.prompt()` prints it for the model.
///
/// Composite card names use the Block/Item pattern of the other pairs
/// (Tabs/TabItem, ListBlock/ListItem): SnippetBlock/SnippetItem and so
/// on. The 0.17.0 doc notes these blocks also appeared under longer
/// SnippetCardBlock-style names in repo PRs; Block/Item is the name
/// this library generates and renders.
///
/// The canonical library constructor. `openUIMvpLibrary` below is a
/// deprecated alias with identical results, kept for compatibility;
/// it now returns the full library, not just the original 25-component
/// MVP. (Deprecation is documented here rather than via @Deprecated,
/// so existing callers do not flood `flutter analyze` with info
/// diagnostics until the migration guide in Task 9 lands.)
OpenUILibrary openUIStandardLibrary({String root = 'Stack', List<FunctionDef> functions = const []}) {
  return openUIMvpLibrary(root: root, functions: functions);
}

OpenUILibrary openUIMvpLibrary({String root = 'Stack', List<FunctionDef> functions = const []}) {
  return OpenUILibrary(
    root: root,
    functions: functions,
    components: [
      // ---- Layout & structure (13) ----
      const ComponentDef('Stack', 'Vertical stack container, the generic root.', [
        PropDef('children', _nodes, required: true),
      ]),
      const ComponentDef('Card', 'Card container, the chat root.', [
        PropDef('children', _nodes, required: true),
      ]),
      const ComponentDef('Tabs', 'Tabbed container; pass TabItem nodes as a list.', [
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('TabItem', 'One tab: label and its content nodes.', [
        PropDef('label', _s, required: true),
        PropDef('children', _nodes, required: true),
      ]),
      const ComponentDef('Accordion', 'Collapsible panels; pass AccordionItem nodes.', [
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('AccordionItem', 'One collapsible panel: label and its content.', [
        PropDef('label', _s, required: true),
        PropDef('children', _nodes, required: true),
      ]),
      const ComponentDef('Steps', 'Step list; pass StepsItem nodes.', [
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('StepsItem', 'One step: label and its content nodes.', [
        PropDef('label', _s, required: true),
        PropDef('children', _nodes),
      ]),
      const ComponentDef('Carousel', 'Swipeable pages; pass content nodes.', [
        PropDef('children', _nodes, required: true),
      ]),
      const ComponentDef('Separator', 'Divider line between blocks.', []),
      const ComponentDef('Modal', 'Dialog-style container; rendered inline as a titled card.', [
        PropDef('title', _s),
        PropDef('children', _nodes, required: true),
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
      const ComponentDef('CardHeader', 'Card title and subtitle.', [
        PropDef('title', _s, required: true),
        PropDef('subtitle', _s),
      ]),
      const ComponentDef('TextContent', 'Body text. variant: small, normal, large, large-heavy.', [
        PropDef('text', _s, required: true),
        PropDef('variant', _s, defaultValue: 'normal'),
      ]),
      const ComponentDef('Text', 'Plain inline text.', [
        PropDef('text', _s, required: true),
      ]),
      const ComponentDef('BoldText', 'Bold inline text.', [
        PropDef('text', _s, required: true),
      ]),
      const ComponentDef('MarkdownRenderer', 'Markdown text rendered by flutter_markdown_plus (full Markdown).', [
        PropDef('text', _s, required: true),
      ]),
      const ComponentDef('Callout', 'Tip/warning block. variant: info, warning, error.', [
        PropDef('text', _s, required: true),
        PropDef('variant', _s, defaultValue: 'info'),
      ]),
      const ComponentDef('TextCallout', 'Text tip block. variant: info, warning, error.', [
        PropDef('text', _s, required: true),
        PropDef('variant', _s, defaultValue: 'info'),
      ]),
      const ComponentDef('Image', 'Single image from a network URL.', [
        PropDef('src', _s, required: true),
        PropDef('alt', _s),
      ]),
      const ComponentDef('ImageBlock', 'Image with an optional caption.', [
        PropDef('src', _s, required: true),
        PropDef('caption', _s),
      ]),
      const ComponentDef('ImageGallery', 'Horizontal gallery; images is a list of URLs.', [
        PropDef('images', _l, required: true),
      ]),
      const ComponentDef('ImageText', 'Small image beside text.', [
        PropDef('src', _s, required: true),
        PropDef('text', _s, required: true),
      ]),
      const ComponentDef('ImageTextLarge', 'Large image above text.', [
        PropDef('src', _s, required: true),
        PropDef('text', _s, required: true),
      ]),
      const ComponentDef('IconText', 'Icon plus text; icon is a name like "search".', [
        PropDef('icon', _s, required: true),
        PropDef('text', _s, required: true),
      ]),
      const ComponentDef('CodeBlock', 'Code block; language is a hint string.', [
        PropDef('code', _s, required: true),
        PropDef('language', _s),
      ]),
      const ComponentDef('InlineHeader', 'Inline heading text.', [
        PropDef('text', _s, required: true),
      ]),
      const ComponentDef('Icon', 'Icon by name like "search"; also used as Tag.icon.', [
        PropDef('name', _s, required: true),
      ]),
      // ---- Data display (21) ----
      const ComponentDef('Table', 'Columnar table; pass Col nodes as a list.', [
        PropDef('columns', _nodes, required: true),
      ]),
      const ComponentDef('Col', 'One table column: label and a list of cell values.', [
        PropDef('label', _s, required: true),
        PropDef('values', _l, required: true),
      ]),
      const ComponentDef('EditableTable', 'Table whose cells are editable text fields. bind: when true, each cell writes to form state under "<statementId>:<columnLabel>:<row>".', [
        PropDef('columns', _nodes, required: true),
        PropDef('bind', PropType.boolean),
      ]),
      const ComponentDef('BarChart', 'Bar chart: categories plus Series nodes.', [
        PropDef('categories', _l, required: true),
        PropDef('series', _nodes, required: true),
      ]),
      const ComponentDef('LineChart', 'Line chart: categories plus Series nodes.', [
        PropDef('categories', _l, required: true),
        PropDef('series', _nodes, required: true),
      ]),
      const ComponentDef('AreaChart', 'Area chart: categories plus Series nodes.', [
        PropDef('categories', _l, required: true),
        PropDef('series', _nodes, required: true),
      ]),
      const ComponentDef('RadarChart', 'Radar chart: axes plus Series nodes.', [
        PropDef('categories', _l, required: true),
        PropDef('series', _nodes, required: true),
      ]),
      const ComponentDef('HorizontalBarChart', 'Horizontal bar chart: categories plus Series.', [
        PropDef('categories', _l, required: true),
        PropDef('series', _nodes, required: true),
      ]),
      const ComponentDef('Series', 'One chart series: label and numeric values.', [
        PropDef('label', _s, required: true),
        PropDef('values', _l, required: true),
      ]),
      const ComponentDef('PieChart', 'Pie chart; pass Slice nodes as a list.', [
        PropDef('slices', _nodes, required: true),
      ]),
      const ComponentDef('RadialChart', 'Radial chart; pass Slice nodes as a list.', [
        PropDef('slices', _nodes, required: true),
      ]),
      const ComponentDef('SingleStackedBarChart', 'One segmented bar; pass Slice nodes.', [
        PropDef('slices', _nodes, required: true),
      ]),
      const ComponentDef('Slice', 'One pie/radial/stacked slice: label and numeric value.', [
        PropDef('label', _s, required: true),
        PropDef('value', _n, required: true),
      ]),
      const ComponentDef('ScatterChart', 'Scatter chart; pass ScatterSeries nodes.', [
        PropDef('series', _nodes, required: true),
      ]),
      const ComponentDef('ScatterSeries', 'One scatter series: label and Point nodes.', [
        PropDef('label', _s, required: true),
        PropDef('points', _nodes, required: true),
      ]),
      const ComponentDef('Point', 'One scatter point: x and y numbers.', [
        PropDef('x', _n, required: true),
        PropDef('y', _n, required: true),
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
      const ComponentDef('TagBlock', 'Tag list; pass Tag nodes.', [
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('Tag', 'One tag chip; icon is an optional icon name.', [
        PropDef('label', _s, required: true),
        PropDef('icon', _s),
      ]),
      const ComponentDef('EntityList', 'Entity list; items is a list of strings.', [
        PropDef('items', _l, required: true),
      ]),
      const ComponentDef('MetricIndicatorInline', 'Inline metric: label, value, optional change.', [
        PropDef('label', _s, required: true),
        PropDef('value', _any, required: true),
        PropDef('change', _s),
      ]),
      const ComponentDef('MetricIndicatorWithStrikethrough', 'Metric with struck-through old value.', [
        PropDef('label', _s, required: true),
        PropDef('value', _any, required: true),
        PropDef('oldValue', _any),
      ]),
      // ---- Form & input (19) ----
      const ComponentDef('Form', 'Form container; children are inputs and buttons.', [
        PropDef('children', _nodes, required: true),
      ]),
      const ComponentDef('FormControl', 'Field wrapper: label, children, optional hint.', [
        PropDef('label', _s, required: true),
        PropDef('children', _nodes, required: true),
        PropDef('hint', _s),
      ]),
      const ComponentDef('Label', 'Field label text.', [
        PropDef('text', _s, required: true),
      ]),
      const ComponentDef('Input', 'Single-line text input. bind: state key to write to.', [
        PropDef('label', _s, required: true),
        PropDef('bind', _s),
        PropDef('value', _any),
        PropDef('placeholder', _s),
      ]),
      const ComponentDef('TextArea', 'Multi-line text input. bind: state key to write to.', [
        PropDef('label', _s, required: true),
        PropDef('bind', _s),
        PropDef('value', _any),
        PropDef('placeholder', _s),
      ]),
      const ComponentDef('Select', 'Dropdown; pass SelectItem nodes as a list.', [
        PropDef('options', _nodes, required: true),
        PropDef('bind', _s),
      ]),
      const ComponentDef('SelectItem', 'One dropdown option.', [
        PropDef('label', _s, required: true),
        PropDef('value', _any),
      ]),
      const ComponentDef('DatePicker', 'Date picker; writes an ISO date to bind.', [
        PropDef('label', _s, required: true),
        PropDef('bind', _s),
        PropDef('value', _s),
      ]),
      const ComponentDef('Slider', 'Slider; writes a number to bind.', [
        PropDef('label', _s, required: true),
        PropDef('bind', _s),
        PropDef('value', _n),
        PropDef('min', _n, defaultValue: 0),
        PropDef('max', _n, defaultValue: 100),
      ]),
      const ComponentDef('CheckBoxGroup', 'Multi-select group; pass CheckBoxItem nodes.', [
        PropDef('items', _nodes, required: true),
        PropDef('bind', _s),
      ]),
      const ComponentDef('CheckBoxItem', 'One checkbox option.', [
        PropDef('label', _s, required: true),
        PropDef('value', _any),
      ]),
      const ComponentDef('RadioGroup', 'Single-select group; pass RadioItem nodes.', [
        PropDef('items', _nodes, required: true),
        PropDef('bind', _s),
      ]),
      const ComponentDef('RadioItem', 'One radio option.', [
        PropDef('label', _s, required: true),
        PropDef('value', _any),
      ]),
      const ComponentDef('SwitchGroup', 'Switch group; pass SwitchItem nodes.', [
        PropDef('items', _nodes, required: true),
        PropDef('bind', _s),
      ]),
      const ComponentDef('SwitchItem', 'One switch option.', [
        PropDef('label', _s, required: true),
        PropDef('value', _any),
      ]),
      const ComponentDef('Chips', 'Quick-choice chips; pass ChipItem nodes as a list.', [
        PropDef('items', _nodes, required: true),
        PropDef('bind', _s),
      ]),
      const ComponentDef('ChipItem', 'One chip option.', [
        PropDef('label', _s, required: true),
        PropDef('value', _any),
      ]),
      const ComponentDef('OptionCards', 'Selectable cards; pass OptionCard nodes.', [
        PropDef('items', _nodes, required: true),
        PropDef('bind', _s),
      ]),
      const ComponentDef('OptionCard', 'One selectable card: label, optional description.', [
        PropDef('label', _s, required: true),
        PropDef('value', _any),
        PropDef('description', _s),
      ]),
      // ---- Actions & feedback (3) ----
      const ComponentDef('Button', 'Button with an optional action.', [
        PropDef('label', _s, required: true),
        PropDef('action', _act),
      ]),
      const ComponentDef('Buttons', 'Button group; pass Button nodes.', [
        PropDef('children', _nodes, required: true),
      ]),
      const ComponentDef('IconButton', 'Icon button; icon is a name like "search".', [
        PropDef('icon', _s, required: true),
        PropDef('action', _act),
      ]),
      // ---- Dialogue guidance (4) ----
      const ComponentDef('FollowUpBlock', 'Follow-up suggestions; pass FollowUpItem nodes.', [
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('FollowUpItem', 'One follow-up: tapping sends it as the next question.', [
        PropDef('text', _s, required: true),
      ]),
      const ComponentDef('ListBlock', 'List block; pass ListItem nodes.', [
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('ListItem', 'One list item text.', [
        PropDef('text', _s, required: true),
      ]),
      // ---- Composite cards (10) ----
      const ComponentDef('SnippetBlock', 'Snippet card block; pass SnippetItem nodes.', [
        PropDef('title', _s),
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('SnippetItem', 'One snippet item: text and optional action.', [
        PropDef('text', _s, required: true),
        PropDef('action', _act),
      ]),
      const ComponentDef('OverviewBlock', 'Overview card block; pass OverviewItem nodes.', [
        PropDef('title', _s),
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('OverviewItem', 'One overview item: text and optional action.', [
        PropDef('text', _s, required: true),
        PropDef('action', _act),
      ]),
      const ComponentDef('ContextBlock', 'Context card block; pass ContextItem nodes.', [
        PropDef('title', _s),
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('ContextItem', 'One context item: text and optional action.', [
        PropDef('text', _s, required: true),
        PropDef('action', _act),
      ]),
      const ComponentDef('CompositeBlock', 'Composite card block; pass CompositeItem nodes.', [
        PropDef('title', _s),
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('CompositeItem', 'One composite item: text and optional action.', [
        PropDef('text', _s, required: true),
        PropDef('action', _act),
      ]),
      const ComponentDef('VisualBlock', 'Visual card block; pass VisualItem nodes.', [
        PropDef('title', _s),
        PropDef('items', _nodes, required: true),
      ]),
      const ComponentDef('VisualItem', 'One visual item: text, optional image src and action.', [
        PropDef('text', _s, required: true),
        PropDef('src', _s),
        PropDef('action', _act),
      ]),
    ],
  );
}
