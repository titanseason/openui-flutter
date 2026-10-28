# openui_flutter

纯 Dart 移植 OpenUI Lang（1.0 子集）+ Flutter 渲染器。包除 Flutter SDK 外只依赖一项第三方：Markdown 渲染用的 flutter_markdown_plus（见下方 Markdown 说明），其余组件均为自实现（图表为自绘 CustomPainter）。

## 定位

- 不是官方 SDK 的搬运：官方目前只有 React / Vue / Svelte / Angular /
  React Native 等运行时，没有 Flutter/Dart 版。
- 本包现已实现全部 86 个 GenUI 组件（以 @openuidev/react-ui 0.17.0
  的名字去重清单为准：布局 13、内容 16、数据 21、表单 19、操作 3、
  对话引导 4、组合卡片 10），以及解析 OpenUI Lang 所必需的核心语义。
  最初的 25 个 MVP 组件是这 86 个的子集。
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

核心解析器在 `lib/src/lang.dart`，不依赖 Flutter，可单独做 Dart 单元测试。
渲染器在 `lib/src/renderer.dart`，组件定义在 `lib/src/library.dart`。

## 86 个组件

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
用 Block/Item 命名（见 library.dart 头注）；Modal 在树内渲染为带
标题的卡片，不是覆盖层弹窗；渲染器现在会包一层 Material，保证
ListTile/Chip/TextField 等在没有 Scaffold 的宿主里也能用。

Markdown 说明：`MarkdownRenderer` 用 flutter_markdown_plus
（`MarkdownBody`，版本见 pubspec，当前解析为 1.0.12），支持全量
Markdown：标题、列表、表格、链接、引用、代码围栏、行内代码、
粗体/斜体等。包除 Flutter SDK 外只依赖这一项（及它带入的
markdown/args）。

## 用法

```dart
import 'package:openui_flutter/openui_flutter.dart';

final library = openUIMvpLibrary(root: 'Stack');

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

未实现（有意留到下一阶段）：`AgentInterface` 聊天外壳（那是宿主
App 的活，不在组件清单里）、手写层专属能力（主题 ThemeProvider
与 createTheme、引用/来源条、按组件的骨架屏、热力图/漏斗图/
日历热力图/Mini 图表与堆积图例等 0.17 新增原语——这些不在 86 个
GenUI 名字里）、token 级增量解析（现为每 push 全文重解析）、
Modal 真弹窗（现为树内带标题卡片）、EditableTable 状态绑定（现
只改本地显示）、官方 props 1:1 对齐与库 API（extend、toJSONSchema、
提示词选项、自定义动作定义与严格校验）、存储消息完整协议
（formState 恢复、build/parseMessage）、渲染器回调补齐
（onError/onParseResult）、Query 失败的界面态（现只走
onToolError 回调，界面保持骨架屏）、官方用例对照与金测、
pub.dev 发布与 CI。Markdown 全量语法已用 flutter_markdown_plus
补齐，Query/Mutation 真实接线与行内自动补全也已补齐（见上文）。

## 验证

```sh
flutter test
flutter analyze
```
