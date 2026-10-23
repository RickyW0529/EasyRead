# 打通苹果词典查询与恢复提示

- 状态：completed
- 创建日期：2026-10-23
- 负责人：Codex
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

## 背景

划词面板只显示苹果词典标题和橙点。本机 DictionaryServices 返回 7 本启用词典，
资源 URL 均为空，普通单词也无结果；当前代码把资源缺失与词条未收录混为一类并折叠提示。

## 目标与范围

- 目标结果：正常查询完整词条，区分缺少资源与未收录，提供系统词典入口及重试恢复。
- 允许修改路径：AppleDictionary.swift、TTTDictionary.m、EZBaseQueryViewController.m、Localizable.xcstrings、当前任务文档。
- 同任务 history：`docs/histories/2026-10/2026-10-23-connect-apple-dictionary.md`
- 用户限制：保留初始工作树改动；不新增或扩写测试；不进行远程写入。
- 非目标：自动选择词典或代替系统下载词典资源。
- 追加范围：按用户后续截图调整 SelectionPanelView.swift 与 GrammarAnnotatedText.swift；
  将翻译操作放在标题旁，把语法标签放在对应划线下方，完成原生视图渲染截图检查。
  后续按用户澄清改为划线句子在左、解析在右，以细竖线分隔，收紧标签和行距；
  ReadingAssistantHostView.swift 与所有查询窗口共用的控制器负责宽高自适应。
- 验收标准：资源缺失有可操作提示；完整短语传入查询 API；现有相关测试及构建通过。

## 工作计划

1. 核验系统词典 API 和面板调用链。
2. 修复查询、资源发现和结果提示。
3. 运行相关验证，使用 review 技能审查本任务差异。
4. 记录结果、归档计划并创建本地提交。
5. 同步完成追加的前端排版修复，并以截图核验长句与长单词。

## 风险与决策

- DCSGetActiveDictionaries 沿用仅调用一次的约束；资源发现不永久缓存不可用对象。
- 系统资源由 Dictionary.app 管理；无资源时不伪造释义。
- 与用户初始变更无交集，按限定路径提交。

## 进度

- [x] 核验系统词典 API 和面板调用链。
- [x] 实现查询和恢复提示。
- [x] 验证及审查。
- [x] history 与归档。
- [x] 记录本地提交暂缓：额外运行的 ReverseTranslationTests 存在断言失败与测试宿主异常退出；未修改该测试及其语言切换行为。

## 验证

- 沙箱外只读 DictionaryServices 探针：7 本启用词典均无资源 URL，apple 无结果。

- 最终 `xcodebuild test -only-testing:EasyReadTests/AppleDictionaryTests`：构建及 2 个测试通过。
- `git diff --check` 和 String Catalog JSON 解析通过。
- 原生视图截图：760pt 深色左右两栏、360pt 浅色单栏；按钮位置、标签、横线和标点可读。
- 实际应用重启后，长段落窗口自动扩至 760pt，内容增长后高度达到屏幕限制并使用滚动。
- 系统屏幕截图命令返回无法捕获，因此截图 QA 使用同一生产视图的原生渲染预览；非远程 AI 输出验证。
- review：冻结初始 HEAD 和 7 个生产文件哈希，核对调用链、并发结果、窗口尺寸和截图；无待修复 finding。
- 限制：本机未下载系统词典资源，无法验证真实词条 HTML 命中与下载后恢复；未新增测试。

## 完成条件

- 实现、验证、审查和 history 完成后归档；环境限制如实记录。
