# 划词面板换行与语言箭头间距

- 状态：completed
- 创建日期：2026-10-22
- 负责人：Grok
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `Grok`
- **Model:** `Grok 4.7`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

## 背景

语法分析把每个成分当成不可换行的整块。短成分独占一行后，右侧留下大片空白；下一块比面板更宽时直接画出窗口。语言按钮用系统按钮的默认图文间距，箭头贴着「简体中文」。

## 目标与范围

- 目标结果：语法原文在面板宽度内换行，成分标签也不再溢出；语言箭头与文字、胶囊边缘都留出间距。
- 允许修改路径：
  - `EasyRead/Swift/Feature/ReadingAssistant/SelectionPanelView.swift`
  - `docs/exec-plans/active/2026-10-22-selection-panel-overflow.md`
  - `docs/histories/2026-10/2026-10-22-selection-panel-overflow.md`
- 同任务 history：`docs/histories/2026-10/2026-10-22-selection-panel-overflow.md`
- 用户限制：只修这两处布局，不改解析结果和颜色规则。
- 非目标：重做窗口框架，不新增测试。
- 验收标准：长句语法不裁切、短成分右侧不再空出整行；语言箭头与文字分开。

## 工作计划

1. 语法原文改成按宽度换行的下划线句子，成分标签单独换行。
2. 解释文字取消两行省略，避免裁切后留下空白。
3. 语言按钮用固定内边距和箭头间距。
4. 构建并用同一句截图核对。

## 风险与决策

- 成分标签不再压在对应词组正下方，避免长词组无法和短词组并排时产生空洞和溢出。颜色仍来自 `GrammarRole`。

## 进度

- [x] 换行与箭头间距
- [x] 构建和截图

## 验证

- `xcodebuild build`（Debug，agent DerivedData，`-skipPackageUpdates -onlyUsePackageVersionsFromResolvedFile`）：`** BUILD SUCCEEDED **`。
- 调试应用打开 “The purpose of his notes is to introduce economists to quantitative modeling of infectious disease dynamics.”，并查看窗口截图、语言胶囊放大图和语法区裁剪图。长句在面板内换行，“infectious disease dynamics.” 完整可见；短主语右侧不再空出半行；解释不再以界面省略号截断。语言箭头距文字约 11pt，距胶囊右缘约 12pt。对照用户原图，旧箭头墨迹贴着胶囊右缘。

## 完成条件

- 构建通过，截图确认长句和语言按钮。
- history 写入 `docs/histories/2026-10/`，本计划移到 `docs/exec-plans/completed/2026-10/`。
