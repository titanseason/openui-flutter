# OpenUI Flutter SDK 设计规约（2026-10-28，已落地版）

本文档是 2026-10-28 brainstorm 方案的落地版：一个包、内部
分层，不做多包拆分；API 名以实际 shipped 代码为准，与提案
不一致的地方以本文件为准（差异见文末）。

## 定位

- 纯 Dart 移植 OpenUI Lang（1.0 子集）+ Flutter 渲染器。
- 不是官方 SDK 的搬运：官方目前只有 React / Vue / Svelte /
  Angular / React Native 等运行时，没有 Flutter/Dart 版。
- 组件库即契约：`OpenUILibrary.prompt()` 按组件名、props 顺序、
  描述生成给模型的系统提示，模型只能用库里的组件。

## 分层（一个包，内部单向依赖）

```
OpenUI Lang 文本（流式）
  -> StreamingParser（按行切分，未完成行经 autocloser 后先渲染）
  -> Parser（语句、表达式、前向引用、$变量、动作、Query/Mutation
     请求、错误码）
  -> ElementNode 树（IR）
  -> OpenUIRenderer（Flutter Widget，按库定义把节点映射成 Widget；
     Query/Mutation 经 toolProvider 执行）
```

| 层 | 文件 | 职责 |
|---|---|---|
| Lang | `lib/src/lang.dart` | 行语句、表达式、$变量、函数、动作、Query/Mutation 请求、错误码、`StoredMessage` 解析 |
| Library | `lib/src/library.dart` | 86 GenUI + 9 扩展组件的定义（名、props 顺序、描述）、`extend`、`prompt` |
| Registry | `lib/src/registry.dart` | 不可变自定义构建器注册表（`withBuilder` 返回新实例） |
| Controller | `lib/src/controller.dart` | 表单状态、Query 数据与失败态、动作分发、流式缓冲；`ChangeNotifier` |
| Theme | `lib/src/theme.dart` | `OpenUIThemeData`（三色 + `chartPalette` + `cardRadius` + 骨架屏/错误注入点）、light/dark |
| Renderer | `lib/src/renderer.dart` | 节点 → Widget；控制器模式时只是控制器的视图 |
| Primitives | `lib/src/primitives.dart` | `Skeleton` / `TableSkeleton` / `Citation` / `Sources` |
| Charts | `lib/src/extra_charts.dart`、`lib/src/extra_widgets.dart` | fl_chart 常规图表 + 自绘 Heatmap/Funnel/CalendarHeatmap |
| Agent shell | `lib/src/agent/` | `AgentInterface` 聊天外壳（见下） |

依赖方向：Renderer → Controller/Theme/Registry/Library/Lang；
Controller → Lang/Registry/Theme。Lang 本身不调用 Flutter API，
但它 import `registry.dart`（见“已知取舍”）。

## 公开 API（`package:openui_flutter/openui_flutter.dart`）

### 渲染

```dart
// 旧参数模式（仍可用）
OpenUIRenderer(
  library: openUIStandardLibrary(),
  response: langText,
  isStreaming: false,
  toolProvider: (tool, params) async => ...,
  onAction: (event) {},
  onToolError: (tool, error) {},
  onParseResult: (errors) {},
  onError: (error) {},
)
// 控制器模式（推荐）：控制器优先于 response / onAction /
// toolProvider / initialState；动作走 onAction 流，错误走 onError 流。
final controller = OpenUIController(
  library: openUIStandardLibrary(),
  toolProvider: ...,
  theme: OpenUIThemeData.light(),
  registry: ...,
  initialState: const {},
);
controller.push(chunk);
controller.finish();
OpenUIRenderer(library: library, controller: controller)
```

### 库与扩展

```dart
openUIStandardLibrary({String root = 'Stack', List<FunctionDef> functions = const []})
// openUIMvpLibrary 是同义旧名，仍可用，暂无 @Deprecated 注解（见下）。

library.extend(
  components: [...],  // 按名替换已有组件定义
  remove: [...],      // 删组件；同名新增优先于删除
  functions: [...],   // 自定义函数
  actions: [...],     // 自定义动作定义（严格校验，见下）
  builders: {...},    // 自定义构建器，存在库的 registry 上
);
library.prompt({preamble, additionalRules, examples, includeBuiltins});
```

构建器查找顺序：渲染器显式 `registry` 参数 > 控制器的 `registry` >
库自带的 `registry` > 内置渲染。`openUIMvpLibrary()` 的组件名与
位置参数顺序是破坏性变更红线。

### 主题与自定义

- `OpenUIThemeData{colors, chartPalette, cardRadius = 12,
  skeletonBuilder, errorBuilder}`，`light()` / `dark()`。
- 宿主自定义 = 换主题 + 换构建器（`ComponentRegistry.withBuilder`
  替换内置组件，或 `extend` 新增组件）。更细的排版/间距字段目前
  没有，需要用户再定。
- 示例：`example/` 的“主题与自定义组件”屏同屏演示主题切换与
  Callout 替换，是该能力的验收演示。

### Query / Mutation 规则

- Query 未返回且无初始值时，依赖它的数据先渲染骨架屏
  （`QueryLoading` 穿过字段访问、索引访问、运算与内置函数）；
  有初始值时先渲染初始值，返回后替换。
- 失败的 Query 不重试，只有显式 `@Run` 重取；失败的 Mutation
  停止该动作列表的后续动作；`@Run(Mutation)` 成功后重取全部查询。
- `$变量` 变化导致 Query 参数变化时重取；流式时表单与按钮禁用；
  半行 Query 不触发工具调用。
- 失败的 Query 在界面上露出错误态（主题 `errorBuilder`，否则
  `数据加载失败：<tool>`）；Table 列里的失败 Query 同样露出错误，
  不再退化为空列；加载中的 Query 列渲染 `TableSkeleton`。
- 流式是“每 push 全文重解析 + 最后一行自动补全”，不是 token 级
  增量 AST diff。

### 函数与动作

- 自定义函数：`defineFunction`（名字、描述、参数、可选返回值类型、
  纯同步实现）；参数校验按官方规则（字面量错 `type-mismatch`、
  必填缺失 `missing-required`、必填 null `null-required`、超参
  `excess-args` 截断后继续跑）；内置函数 14 个（Count/Sum/Avg/
  Min/Max/First/Last/Filter/Sort/Round/Abs/Floor/Ceil/Each）。
- 自定义动作校验是严格的：类型错、必填缺失、超参都让整个动作
  无操作并发出 `runtime-error`（不截断，因为动作有副作用）；
  未声明的动作原样透传为事件。

### AgentInterface 聊天外壳

```dart
AgentInterface(
  storage: AgentStorage,  // listThreads / loadThread / saveThread / deleteThread
  llm: AgentLlm,          // Stream<String> send(List<AgentMessage> history, String prompt)
  library: ..., toolProvider: ..., onAction: ...,
  slots: AgentSlots(...), // sidebar / sidebarHeader / sidebarFooter /
                          // mobileHeader / threadHeader / welcome /
                          // composer / workspace，有值整体替换，无值走默认
  toolCalls: () => ...,   // 只读时间线
  artifacts: () => ...,   // 右侧工作区面板
)
```

外壳不调模型 API、不执行工具。默认：侧边栏线程列表（>= 700px
为 280 宽侧栏，窄屏收进抽屉）、线程头重命名/删除、欢迎态、流式
composer；工作区面板只在有 artifact 时渲染。

### 存储消息协议

`StoredMessage` / `parseStoredMessage`：围栏外的散文是说明文字，
最后一个围栏程序获胜；`]]>openui:context` 形式的 JSON formState
会被返回并合并进解析状态；畸形 context JSON 被忽略。

## 依赖与最低版本

- flutter_markdown_plus 1.0.12（Markdown 渲染）。
- fl_chart 1.3.0（常规图表；热力图/漏斗图/日历热力图无 fl_chart
  等价物，仍自绘）。Flutter 最低版本 >= 3.27.4（fl_chart 的要求）。
- 其余全部自实现；CodeBlock 为纯文本，无高亮依赖。

## 已知取舍（裁决记录）

- `lang.dart` 与 `registry.dart` 的耦合：Task 3 要求把构建器存在
  库上，与“纯 Dart 核心”的架构冲突；裁决是接受耦合（解析/求值
  逻辑本身不用 Flutter API，只有 registry 字段带构建器），纯度
  恢复留待最终评审裁决。
- CodeBlock 无高亮：syntax_highlight 曾接过又被回退（传递依赖带
  原生插件、抬高 SDK 最低版本）；更轻路线已调研，用户决定先
  保持纯文本，未经新决定不加。
- `openUIMvpLibrary` 暂无 `@Deprecated` 注解：仓库内仍有几十处旧
  调用，加注解会让 `flutter analyze` 刷满 info 级提示；迁移指南
  已指引新代码用 `openUIStandardLibrary()`，注解与否留待发 1.0
  时决定。
- SDK 最低版本声明不一致：包声明 Dart ^3.5.0，fl_chart 要求
  Dart >= 3.6.2；pub 强制执行 fl_chart 自己的约束所以解析无碍，
  但声明值留待发 1.0 前统一。

## 与 brainstorm 提案的差异

- 提案说 AgentInterface 不进 SDK 包；实际 Tasks 7–8 已把它做进
  包内（`lib/src/agent/` 并导出），本文件以实际为准。
- 提案的“手写层主题/引用/新增原语图表”已落地为 Theme、
  Primitives、Extra charts 三部分，不再是待办。
- 提案未点名的 fl_chart 迁移是用户在执行中途定的（2026-10-28），
  已落地，见“依赖与最低版本”。

## 不在范围内

- Gateway / Autofix / 服务端解析成 JSON 树（用户定走纯 Dart 移植）。
- token 级增量解析、官方 props 1:1、官方用例对照与金测（Task 10
  做对照与金测）、pub.dev 发布与 CI、存储消息的完整
  build/parseMessage 往返。
