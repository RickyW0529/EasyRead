## 2026-10-23 | 任务：完善苹果词典接入和自适应阅读面板

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-23-connect-apple-dictionary.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

### 用户请求

打通苹果词典；将朗读、复制移到翻译结果标题旁；语法标签放到对应划线下方，
划线句子和逐项解析左右并排，中间用细竖线分隔，缩小标签和行距；查询窗口按内容和屏幕自适应，
并截图检查可读性。

### 变更

- 苹果词典完整查询含空格、连字符的词条，不再先截取开头的单词。
- 每次查询重新发现词典资源，区分缺少下载资源与未收录；提示保持展开，提供系统词典入口。
- 词典查询先生成局部结果，再检查请求代次后发布，避免旧查询覆盖新结果。
- 翻译操作移动到标题右侧，补充辅助功能标签。
- 语法片段以独立连续横线绘制，标签紧随横线下方，正文 13pt、标签 9pt、片段行高 44pt；
  普通词按词边界换行，超长标识符按完整字符折行，避免裁切与缩小正文。
- 划线句子在左、逐项解析在右；可用内容宽度不足 600pt 时切回单栏并隐藏竖线。
- 所有查询窗口共用按文本自然宽度调整的策略，宽度不超过 760pt 或当前屏幕可用宽度；
  高度按内容及当前屏幕限制调整，超出后滚动，同次查询保留用户手动调整的宽度。
- 保留任务开始前的所有工作树变更，未新增或扩写测试。

### 设计意图

沿用 DictionaryServices、现有 HTML 渲染和统一查询窗口控制器。系统词典资源由 Dictionary.app
管理；资源缺失时给出可操作提示。标注的文本、横线和标签使用相同的布局测量，避免字形造成
横线断开；解释与标注并排，减少长段落下的纵向堆叠。

### 验证

- `xcodebuild test -workspace EasyRead.xcworkspace -scheme EasyRead -derivedDataPath <agent-derived-data> -skipPackageUpdates -onlyUsePackageVersionsFromResolvedFile -only-testing:EasyReadTests/AppleDictionaryTests CODE_SIGNING_ALLOWED=NO`：最终构建和 2 个现有测试通过。
- 额外运行 `ReverseTranslationTests`：存在断言失败与测试宿主异常退出；未把该检查写成通过，
  未修改语言反转路径或测试。按自动提交规则暂缓本地提交。
- `git diff --check`、String Catalog JSON 解析：通过。
- 沙箱外系统 API 只读核验：7 本已启用词典的资源 URL 均为空，普通单词也无词条；
  因此未宣称真实词条命中或下载后恢复已经验证。
- 原生视图截图检查：760pt 深色左右两栏、360pt 浅色单栏，检查按钮位置、连续横线、
  标签、标点与长解析换行。预览复用生产视图，使用示例语法数据，未将其作为真实 AI 输出验证。
- 真实应用重启到新构建后，长段落窗口扩至 760pt，内容增长后高度达到屏幕限制。
  系统屏幕截图命令返回无法捕获，使用上述原生渲染截图完成视觉检查。
- review：以任务开始前 HEAD 和初始工作树为基线，冻结 7 个生产文件的内容摘要并复验，
  核对词典调用链、结果代次、窗口限制和排版；未发现待修复的本次引入 finding。

### 受影响文件

- `EasyRead/App/Localizable.xcstrings`
- `EasyRead/Swift/Service/Dictionary/AppleDictionary/AppleDictionary.swift`
- `EasyRead/objc/Libraries/DictionaryKit/TTTDictionary.m`
- `EasyRead/Swift/Feature/ReadingAssistant/SelectionPanelView.swift`
- `EasyRead/Swift/Feature/ReadingAssistant/GrammarAnnotatedText.swift`
- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAssistantHostView.swift`
- `EasyRead/objc/ViewController/Window/BaseQueryWindow/EZBaseQueryViewController.m`
- `docs/exec-plans/completed/2026-10/2026-10-23-connect-apple-dictionary.md`
- `docs/histories/2026-10/2026-10-23-connect-apple-dictionary.md`

### 后续事项

- 在系统“词典”中下载所需词典，完成真实词条命中及下载后重试的人工验证。
- 调查额外反向翻译测试的失败；本地提交暂缓，未 push。
