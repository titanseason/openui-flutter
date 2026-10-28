# openui_flutter

纯 Dart 移植 OpenUI Lang（1.0 子集）+ Flutter 渲染器。包除 Flutter SDK 外只依赖两项第三方：Markdown 渲染用的 flutter_markdown_plus，和图表用的 fl_chart（热力图/漏斗图/日历热力图没有 fl_chart 等价物，仍为自绘 CustomPainter；CodeBlock 为纯文本，无高亮依赖）。依赖与最低版本见下方“依赖”一节。

## 定位

- 不是官方 SDK 的搬运：官方目前只有 React / Vue / Svelte / Angular /
  React Native 等运行时，没有 Flutter/Dart 版。
- 本包现已实现全部 86 个 GenUI 组件（以 @openuidev/react-ui 0.17.0
  的名字去重清单为准：布局 13、内容 16、数据 21、表单 19、操作 3、
  对话引导 4、组合卡片 10），以及解析 OpenUI Lang 所必需的核心语义。
  最初的 25 个 MVP 组件是这 86 个的子集。另有 9 个扩展图表组件
  （HeatmapChart、FunnelChart、CalendarHeatmap、MiniBarChart、
  MiniLineChart、StackedLegend、BarChartCondensed、LineChartCondensed、
  AreaChartCondensed），库内组件总数为 95。
- 生成侧（系统提示）由库定义导出：`OpenUILibrary.prompt()` 会按组件名、
  props 顺序、描述生成给模型的说明，模型只能用库里的组件。

## 架构

```
OpenUI Lang 文本（流式）
  -> StreamingParser（按行切分，未完成行经 autocloser 后先渲染）
  -> Parser（语句、表达式、前向引用、$变量、动作、Query/Mutation 请求、错误码）
  -> ElementNode 树（IR，与 Flutter 无关）
  -> OpenUIRenderer（Flutter Widget，按库定义把节点映射成 Widget；
     Query/Mutation 经 toolProvider 执行）
```

核心解析器在 `lib/src/lang.dart`。注意：解析/求值逻辑本身没有用
Flutter API，但 `lang.dart` 为了在库上挂接自定义构建器而 import 了
`registry.dart`（Flutter widgets），所以它目前不能被纯 Dart 包直接
import——这是 Task 3 留下的耦合，见下方“已知取舍”。渲染器在
`lib/src/renderer.dart`，组件定义在 `lib/src/library.dart`。

## 组件清单（86 个 GenUI + 9 个扩展图表 = 95）

9 个扩展图表见下方“图表”一节（HeatmapChart、FunnelChart、
CalendarHeatmap、MiniBarChart、MiniLineChart、StackedLegend、
BarChartCondensed、LineChartCondensed、AreaChartCondensed）。

布局 13：Stack, Card, Tabs, TabItem, Accordion, AccordionItem, Steps,
StepsItem, Carousel, Separator, Modal, SectionBlock, SectionItem。

内容 16：CardHeader, TextContent, Text, BoldText, MarkdownRenderer,
Callout, TextCallout, Image, ImageBlock, ImageGallery, ImageText,
ImageTextLarge, IconText, CodeBlock, InlineHeader, Icon。

数据 21：Table, Col, EditableTable, BarChart, LineChart, AreaChart,
RadarChart, HorizontalBarChart, Series, PieChart, RadialChart,
SingleStackedBarChart, Slice, ScatterChart, ScatterSeries, Point,
TagBlock, Tag, EntityList, MetricIndicatorInline,
MetricIndicatorWithStrikethrough。

表单 19：Form, FormControl, Label, Input, TextArea, Select, SelectItem,
DatePicker, Slider, CheckBoxGroup, CheckBoxItem, RadioGroup, RadioItem,
SwitchGroup, SwitchItem, Chips, ChipItem, OptionCards, OptionCard。

操作 3：Button, Buttons, IconButton。

对话引导 4：FollowUpBlock, FollowUpItem, ListBlock, ListItem。

组合卡片 10：SnippetBlock/SnippetItem, OverviewBlock/OverviewItem,
ContextBlock/ContextItem, CompositeBlock/CompositeItem,
VisualBlock/VisualItem。

注意：props 仍是 MVP 精简版，不是官方 Zod 的 1:1 复刻；组合卡片
用 Block/Item 命名（见 library.dart 头注）；Modal 渲染为真正的
AlertDialog（同一位置出现新的 Modal 语句时会重新打开，关闭后不再
重开）；渲染器现在会包一层 Material，保证
ListTile/Chip/TextField 等在没有 Scaffold 的宿主里也能用。

Markdown 说明：`MarkdownRenderer` 用 flutter_markdown_plus
（`MarkdownBody`，版本见 pubspec，当前解析为 1.0.12），支持全量
Markdown：标题、列表、表格、链接、引用、代码围栏、行内代码、
粗体/斜体等。`CodeBlock` 是纯文本等宽渲染，没有引入高亮依赖
（syntax_highlight 曾接过又因传递依赖过重被回退，见“已知取舍”）。

## 依赖

- flutter_markdown_plus 1.0.12（Markdown 渲染；带入 markdown/args）。
- fl_chart 1.3.0（全部常规图表；带入 equatable）。热力图、漏斗图、
  日历热力图没有 fl_chart 等价物，仍为自绘 CustomPainter。
- 最低版本：Flutter >= 3.27.4（fl_chart 1.3.0 的要求；包的声明值已
  跟着抬到这一档）。另注意：包声明的 Dart SDK 仍是 ^3.5.0，而
  fl_chart 1.3.0 要求 Dart >= 3.6.2——pub 会强制执行 fl_chart 自己的
  约束，实际解析不出问题，但声明值本身不一致，留待发 1.0 前统一。

## 用法

```dart
import 'package:openui_flutter/openui_flutter.dart';

final library = openUIStandardLibrary(root: 'Stack');

OpenUIRenderer(
  library: library,
  response: '''
root = Stack([header, chart, cta])
header = CardHeader("Q1 收入", "全部业务线")
chart = BarChart(["1月", "2月", "3月"], [rev])
rev = Series("收入", [120, 145, 180])
cta = Button("查看明细", @ToAssistant("查看明细"))
''',
  isStreaming: false,
  onAction: (event) {
    // event.type: toAssistant / openUrl / set / reset / run / custom
    // event.params: 动作参数
  },
)
```

流式用法：`isStreaming: true`，每收到一个 chunk 就把累计文本传给
`response`；未定义的前向引用会先渲染骨架屏，流结束前不报 `no-root`。
更精细的流式控制用 `StreamingParser.push(chunk)`：已完成的行正常解析，
未完成行经 `autoCloseOpenUI` 补全后先渲染（未闭合字符串、列表、调用
都能先出界面）；半行写出的 Query 不会触发工具调用，等该行换行后才
注册为请求。注意：本实现是“每 push 全文重解析 + 最后一行自动补全”，
不是 token 级增量 AST diff；典型聊天回答长度下足够，超长文本会随
长度变慢。

## 控制器模式（推荐）

旧参数（`response` / `toolProvider` / `onAction` 等）仍可用，但新代码
请用 `OpenUIController`：表单状态、Query 数据与失败态、动作分发、
流式缓冲都归控制器管，渲染器只是它的视图；宿主可以在 widget 树外
驱动同一份 UI、读 `formState`。

```dart
final controller = OpenUIController(
  library: openUIStandardLibrary(),
  toolProvider: (tool, params) async => api.call(tool, params),
  theme: OpenUIThemeData.light(),
  registry: ComponentRegistry().withBuilder(
    'Callout',
    (context, node, renderChild) => MyCallout(node.props['text'] as String),
  ),
);
controller.push(chunk);
controller.finish(); // 流结束

OpenUIRenderer(library: library, controller: controller)
// 控制器模式下 controller 优先于 response / onAction / toolProvider /
// initialState；动作走 controller.onAction 流，错误走 onError 流。
```

## 注册表与自定义组件

```dart
// 替换内置组件：同名构建器优先于内置渲染。
final registry = ComponentRegistry().withBuilder(
  'TextContent',
  (context, node, renderChild) => MyText(node.props['text'] as String),
);
// 新增组件：先在库里注册定义，再配构建器（或用 extend 一步做完）。
final library = openUIStandardLibrary().extend(
  components: [ComponentDef('PriceTag', '...', [PropDef('price', PropType.number)])],
  builders: {'PriceTag': (context, node, renderChild) => Text('¥${node.props['price']}')},
);
```

查找顺序：渲染器显式 `registry` 参数 > 控制器的 `registry` >
库自带的 `registry`（`extend(builders: ...)` 存的地方）> 内置渲染。
`ComponentRegistry` 不可变，`withBuilder` 返回新实例。

## 控制器与主题

`OpenUIThemeData` 只有三色（`primary / surface / onSurface`）+
图表配色 `chartPalette` + `cardRadius`（默认 12）+ 两个注入点：
`skeletonBuilder`（骨架屏）和 `errorBuilder`（Query 失败界面）。
`OpenUIThemeData.light()` / `.dark()` 开箱即用；更细的排版/间距
字段目前没有，需要再加。控制器模式下主题来自控制器，否则用浅色。

## 库 API

```dart
final library = openUIStandardLibrary()
    .extend(
      components: [...],   // 按名替换已有组件定义
      remove: ['OldCard'], // 删组件；同名新增优先于删除
      functions: [...],    // 自定义函数（见“函数”）
      actions: [...],      // 自定义动作定义（严格校验）
      builders: {...},     // 自定义构建器，存在库的 registry 上
    );
library.prompt(
  preamble: '...', additionalRules: [...],
  examples: [...], includeBuiltins: true,
); // 生成给模型的系统提示：组件名、props 顺序、描述、函数
```

自定义动作校验是严格的：类型错、必填缺失、超参都会让整个动作
无操作，并发出 `runtime-error`（函数超参是截断后继续跑，动作不
截断，因为动作有副作用）。未在库里声明的动作原样透传为事件。

## 手写原语

`Skeleton`（`count` 条占位条）、`TableSkeleton`（占位表格）、
`Citation`（`[n]` 角标，`onTap` 可选）、`Sources`（标题行列表，
`faviconUrl` 有值时显示网络图标）。Table 的列里有加载中的 Query
时渲染 `TableSkeleton`；有失败的 Query 时露出错误界面（主题
`errorBuilder`，否则 `数据加载失败：<tool>`），不再悄悄变空列。

## 图表

常规图表（Bar/Line/Area/HorizontalBar/Pie/Radar/Radial/
SingleStackedBar/Scatter）走 fl_chart，颜色全部取主题
`chartPalette`；扩展组件里 Heatmap/Funnel/CalendarHeatmap 仍自绘，
Mini（高 48，无轴无图例）、Condensed（高 120，无图例）走 fl_chart，
StackedLegend 只画色板与标签、没有图表区。

## AgentInterface 聊天外壳

```dart
AgentInterface(
  storage: myStorage, // AgentStorage：list/load/save/delete 线程
  llm: myLlm,         // AgentLlm：Stream<String> send(history, prompt)
  library: openUIStandardLibrary(),
  toolProvider: (tool, params) async => ...,
  slots: AgentSlots(welcome: (context, state) => MyWelcome()),
  toolCalls: () => currentToolCalls,   // 只读时间线，外壳不执行工具
  artifacts: () => currentArtifacts,  // 右侧工作区面板
)
```

外壳本身不调模型 API、不执行工具：模型由宿主的 `AgentLlm` 实现
提供，工具调用只以只读时间线展示。默认含侧边栏线程列表（>= 700px
为 280 宽侧栏，窄屏收进抽屉）、线程头重命名/删除、欢迎态、流式
composer；`AgentSlots` 的八个槽（sidebar、sidebarHeader、sidebarFooter、
mobileHeader、threadHeader、welcome、composer、workspace）有值时
整体替换对应区域，无值时走默认。

## 迁移指南

### 旧渲染器参数 → 控制器模式

| 旧写法 | 新写法 |
|---|---|
| `OpenUIRenderer(library: l, response: r, toolProvider: p, onAction: f)` | `OpenUIController(library: l, toolProvider: p)` + `OpenUIRenderer(library: l, controller: c)`，动作改订阅 `c.onAction` 流 |
| `response` 累计文本 + `isStreaming: true` | `controller.push(chunk)`，结束时 `controller.finish()` |
| `initialState: {...}` | `OpenUIController(..., initialState: {...})`，之后读 `controller.formState` |
| `onStateUpdate` 回调 | 控制器 `setFormValue` 后读 `formState`，或监听控制器（`ChangeNotifier`） |
| `onToolError` 回调 | 控制器 `onError` 流；失败的 Query 本身已在界面上露出错误态 |

控制器模式下控制器优先，旧参数与控制器混传时旧参数被忽略；
只传旧参数时行为与原来一致。

### `openUIMvpLibrary` → `openUIStandardLibrary()`

两者返回同一个库，旧名字仍可用，纯粹是改名：新代码请用
`openUIStandardLibrary()`。自 1.0.0 起旧名字已加 `@Deprecated`
注解（仓库内调用已全部迁移，只剩一条为该别名本身背书的测试）。

### 示例

`example/` 里有四个屏：聊天富回答、业务看板（含 Task 6 留下的
两处人眼复核点：横向柱状图的旋转标题位置、2 类雷达图的补齐
三角形）、表单 + Query、主题切换 + 自定义组件（主题与替换组件
同屏演示）。跑：`cd example && flutter run`；测：`flutter test`
（主包）与 `example` 内的 `flutter test`。

## Query / Mutation

语法沿用官方示例的形状（工具名、参数对象、可选初始值）：

```dart
OpenUIRenderer(
  library: library,
  response: '''
root = Stack([count, btn])
count = TextContent("" + @Count(tickets.rows))
tickets = Query("list_tickets", {"status": "open"}, {"rows": []})
btn = Button("重试", Action([@Run(retry)]))
retry = Mutation("retry_deployment", {"project": "prod"})
''',
  toolProvider: (tool, params) async {
    if (tool == 'list_tickets') return await api.listTickets(params);
    if (tool == 'retry_deployment') return await api.retry(params);
    throw StateError('unknown tool \$tool');
  },
  onToolError: (tool, error) { /* 宿主展示错误 */ },
)
```

规则：Query 未返回且无初始值时，依赖它的数据先渲染为骨架屏
（`QueryLoading` 会穿过字段访问、索引访问、运算与内置函数，直到
直接依赖它的组件）；有初始值时先渲染初始值，返回后替换。
`@Run(查询名)` 只重取该查询；`@Run(Mutation 名)` 执行 Mutation，
成功后重取全部查询，失败则停止该动作列表的后续动作（并发出
`mutationError` 事件）。失败的查询不会每帧重试，只有显式 `@Run`
重取才会再跑。`$变量` 变化导致 Query 参数变化时，渲染器会按新
参数重取。流式进行时表单与按钮会被禁用（`isStreaming: true`）。
索引访问已支持：`tickets.rows[0].status`。

## 已实现 / 未实现

已实现：行语句、位置参数、字面量（字符串/数字/布尔/null）、列表、
对象、字段访问（`data.rows`、`t.priority`）、索引访问（`rows[0]`）、
`Query()/Mutation()` 接线与流式自动补全（见上文专节）、`$变量`、三元表达式、
`+` 连接/加法、前向引用、重定义以后者为准、
`root` 入口及回退规则、`@ToAssistant/@OpenUrl/@Set/@Reset/@Run`、
自定义动作（`@Name(args)` 以事件发出）、错误码
（`unknown-component / missing-required / null-required / type-mismatch /
excess-args / unknown-function / no-root / parse-failed`）。

函数（已补齐）：`defineFunction` 定义自定义函数（名字、描述、参数、
可选返回值类型、纯同步实现，接收按参数名组织的对象，默认值已应用）；
参数校验按官方 Functions 文档：字面量错为 `type-mismatch`、必填缺失为
`missing-required`、必填 null 为 `null-required`、超参为 `excess-args`
（截断后继续跑）、运行时必填 null 静默为 null、运行时类型错与返回值
不匹配为 `runtime-error`；`library.prompt()` 列出内置函数与自定义函数。
内置函数：`Count / Sum / Avg / Min / Max / First / Last / Filter / Sort /
Round / Abs / Floor / Ceil / Each`（内置函数会转换参数，如
`@Sum(["1", 2])` 得 `3`；`@Each` 在模板里绑定循环变量）。

已补齐（本轮之前是“未实现”）：`AgentInterface` 聊天外壳、手写层
原语（主题、引用/来源、骨架屏、热力图/漏斗图/日历热力图/Mini 图表
与堆积图例）、Modal 真弹窗、EditableTable 状态绑定、库 API
（extend、提示词选项、自定义动作定义与严格校验）、存储消息解析
（`StoredMessage` / `parseStoredMessage`，含 formState 恢复）、渲染器
回调（onError/onParseResult）、Query 失败的界面态。

未实现（有意留到下一阶段）：token 级增量解析（现为每 push 全文
重解析）、官方 props 1:1 对齐、官方用例对照与金测（Task 10）、
pub.dev 发布与 CI、存储消息的完整 build/parseMessage 往返。
Markdown 全量语法已用 flutter_markdown_plus 补齐，Query/Mutation
真实接线与行内自动补全也已补齐（见上文）。

## 已知取舍

- `lang.dart` 与 `registry.dart` 的耦合：Task 3 的库上挂接构建器
  要求与计划里“纯 Dart 核心”的架构冲突，裁决是接受耦合（解析/
  求值逻辑本身不用 Flutter API，只有 registry 字段带构建器），纯度
  恢复留待最终评审裁决，不在本任务里重构。
- CodeBlock 无高亮：syntax_highlight 曾接过又被回退（传递依赖带
  原生插件、抬高 SDK 最低版本）；更轻的路线（re_highlight、手写
  高亮）已调研，用户决定先保持纯文本，未经新决定不加。
- SDK 最低版本声明不一致：见“依赖”一节，留待发 1.0 前统一。

## 验证

```sh
flutter test
flutter analyze
```
