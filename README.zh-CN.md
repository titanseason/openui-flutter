# openui_flutter

[English](./README.md) | [中文](./README.zh-CN.md)

OpenUI Lang 1.0 与 82 个通用 GenUI 组件的纯 Dart Flutter 渲染器，
对齐 `@openuidev/react-ui` 0.18.1。它把 Lang 程序（含流式未完成
输入）解析成元素树，再用 Flutter widget 渲染。图表全部自绘；
唯一的第三方依赖是负责 Markdown 的 `flutter_markdown_plus`。

> 状态：尚未发布到 pub.dev。包名 `openui_flutter`，版本 1.0.0，
> `pubspec.yaml` 里的 repository/homepage 仍是 `.invalid` 占位。
> 首次发布之前，请用本地路径依赖：
>
> ```yaml
> dependencies:
>   openui_flutter:
>     path: ../openui-flutter
> ```

## 快速开始

response 模式，一段完整程序：

```dart
import 'package:openui_flutter/openui_flutter.dart';

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

控制器模式，流式输入、表单状态与工具：

```dart
final controller = OpenUIController(
  library: openUIStandardLibrary(),
  toolProvider: (tool, params) async => fetchFromBackend(tool, params),
);
controller.push(chunk); // 每个流式 chunk 调一次
controller.finish();    // 渲染最终程序

OpenUIRenderer(library: controller.library, controller: controller)
```

给模型的系统提示由库本身生成：
`openUIStandardLibrary().prompt()` 会按顺序打印全部组件、props
与描述，模型只能用库里已有的组件。

## 已实现内容

- **Lang 1.0 解析与求值。** 语句只有 `name = Expr` 赋值一种形态。
  表达式覆盖字面量、引用、`$变量`、字段访问、索引、列表/对象
  字面量、调用、`@内置` 函数、动作、三元、二元/一元运算，以及
  `Query`/`Mutation` 请求。前向引用可解析，错误带错误码
  （`unknown-component`、`type-mismatch` 等）。
- **流式与增量解析。** `StreamingParser` 会自动补全未完成的行尾，
  让未完成输入先渲染；渲染器复用增量解析器，流式追加时不再每
  chunk 全文重解析两次。表单编辑时仍全文重算（记忆化渲染只在
  流式追加与宿主重建时受益）。
- **82 个组件，单个库。** `openUIStandardLibrary()` 的根是
  `Stack`。本移植不含聊天库。
- **Query 与 Mutation。** 经宿主的 `toolProvider` 执行，带加载态、
  失败态与 `@Run` 重试界面。宿主自定义工具用 `defineFunction`
  接入，自定义组件用 `OpenUILibrary.extend` 注册。
- **表单。** `Form`/`FormControl` 的状态经 `onStateUpdate`
  （response 模式）或 `controller.formState` 回流。
- **主题。** 见下文。

## 组件（82 个）

- 布局（11）：Stack、Card、Tabs、TabItem、Accordion、AccordionItem、
  Steps、StepsItem、Carousel、Separator、Modal。
- 内容（16）：CardHeader、TextContent、Text、BoldText、
  MarkDownRenderer、Callout、TextCallout、Image、ImageBlock、
  ImageGallery、ImageText、ImageTextLarge、IconText、CodeBlock、
  InlineHeader、Icon。
- 数据（21）：Table、Col、EditableTable、BarChart、LineChart、
  AreaChart、RadarChart、HorizontalBarChart、Series、PieChart、
  RadialChart、SingleStackedBarChart、Slice、ScatterChart、
  ScatterSeries、Point、TagBlock、Tag、EntityList、
  MetricIndicatorInline、MetricIndicatorWithStrikethrough。
- 表单（19）：Form、FormControl、Label、Input、TextArea、Select、
  SelectItem、DatePicker、Slider、CheckBoxGroup、CheckBoxItem、
  RadioGroup、RadioItem、SwitchGroup、SwitchItem、Chips、ChipItem、
  OptionCards、OptionCard。
- 操作（3）：Button、Buttons、IconButton。
- 列表（2）：ListBlock、ListItem。
- 组合卡片（10）：SnippetCardBlock/SnippetCardItem、
  OverviewCardBlock/OverviewCardItem、ContextCardBlock/ContextCardItem、
  CompositeCardBlock/CompositeCardItem、VisualCardBlock/VisualCardItem。

内置函数（用 `@` 调用）：Count、Sum、Avg、Min、Max、First、Last、
Filter、Sort、Round、Abs、Floor、Ceil、Each。内置动作：ToAssistant、
OpenUrl、Set、Reset、Run。

## 主题

```dart
// 内置：
OpenUIThemeData.light();
OpenUIThemeData.dark();

// 自定义：
OpenUIThemeData(
  colors: const OpenUIColorScheme(
    primary: Colors.blue,
    surface: Colors.white,
    onSurface: Colors.black87,
    // textMuted、border、grid、success、warning、danger、info
    // 省略时取浅色默认值。
  ),
  chartPalette: const [Colors.blue, Colors.green, Colors.orange],
)
```

`OpenUIColorScheme` 是语义化的：`primary` / `surface` /
`onSurface`，外加 `textMuted`（次要文本、图表轴字）、`border`
（图表外框、轴线、tooltip 边框）、`grid`（图表网格线与轨道），
以及 `success` / `warning` / `danger` / `info`（Callout 变体）。
图表的 chrome 经 `ChartColors` 取自主题，系列配色仍独立
（`chartPalette`）。`cardRadius` 与 `skeletonBuilder` /
`errorBuilder` 注入点在 `OpenUIThemeData` 上。

## 图表

8 种图全部用 `CustomPainter` 自绘（不用图表包）：柱状、折线、
面积、横向条、饼、径向、单堆叠条、散点。行为对齐 React：悬停
tooltip（鼠标悬停与触摸拖动；静止点按不显示）、图例点击隐藏
系列或扇区（饼重归一化、径向环保持半径、刻度按全部系列计算
故切换不重算）、恒过零点的 nice 域（含负值）、堆叠条为横向
轨道。

柱状/折线/面积接受 3 个布局属性（位置参数，在 `height` 之后）：
`density`（`compact` 48 / `default` 72 / `spacious` 96px 槽位，
仅滚动模式）、`condensed`（fit 模式：全部分类共享容器宽度，
不滚动，标签稀释截断）、`tickVariant`（`singleLine` /
`multiLine` / `angled`；angled 仅 condensed 生效，标签旋转
−45°）。轴刻度用 React 的数字格式（1000 为 1.0K，以上为
M/B/T）；tooltip 在 100000 以下用千分位，以上用 K/M/B/T。

每个图表 widget 都有 `onTap`，但只对直接用 Dart 构造 widget
的宿主有效：Lang 文本带不了回调，所以 Lang 驱动的图表只可看。

## 架构

```
lib/src/
  core/     Lang、library、registry（语言与注册）
  runtime/  controller、renderer、theme（面向宿主的运行时）
  widgets/  primitives、extra widgets（共享 widget 实现）
  charts/   图表 widget 与 painter（一图型一文件）
```

```
Lang 文本（流式）
  -> StreamingParser（按行切分，autocloser 补全未完成行尾）
  -> 解析与求值（语句、表达式、前向引用、$变量、动作、
     Query/Mutation、错误码）
  -> ElementNode 树（与 Flutter 无关的 IR）
  -> OpenUIRenderer（节点映射成 Flutter widget；
     Query/Mutation 经 toolProvider 执行）
```

解析/求值本身不用 Flutter API，但 `core/lang.dart` import 了
`core/registry.dart`（上面挂着 widget 构建器），所以语言核心
目前不能被纯 Dart 包直接 import。这是已知的取舍，不是疏忽。

## 与 React 的差异

- **默认配色。** 不给配色时，本移植用蓝/绿/橙/紫/青/红；
  React 的无配色回退是单色蓝渐变（OCEAN）。要对齐请传
  `chartPalette`。
- **无入场动画。** React 的入场动画默认也是关的。
- **onClick 仅直接构造 widget 可用**，如上所述。
- **Markdown** 来自 `flutter_markdown_plus`；**CodeBlock 为纯文本**
  （无语法高亮依赖）。
- **不存在与 React 渲染的像素级对齐验证。** 金测只跟自己比，
  且测试字体是 Ahem（文字全是方块），所以字体度量、字号、
  中文换行都未对照 React 验过。
- **无聊天库。** React 有通用库和聊天库两个库；本移植只实现
  通用库。

## 开发

```sh
flutter test        # 主包测试
flutter analyze     # 主包 + 示例
cd example && flutter test
```

金测在 `test/goldens/` 与 `test/charts/goldens/`。用
`flutter test --update-goldens` 重新生成，生成后先目视检查再
提交：重新生成的金测是一项主张，不是“通过”。`example/` 有
4 个屏（富回答、业务看板、表单 + Query、主题与自定义组件）。

深入阅读：`docs/react-1.0-diff/` 存着 React 0.18.1 的对齐证据
（清单、props 差异、一致性说明），`CHANGELOG.md` 记录每次
变更（含破坏性变更）。

## License

Apache License 2.0，见 [LICENSE](./LICENSE)。
