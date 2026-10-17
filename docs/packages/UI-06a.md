# UI-06a Godot 换 G2 界面（一）：公共组件 + 选章、选关、设置、暂停

状态：**已合并（部分通过）**（2026-10-17，`ui/UI-06a` @ `bc88315`）。G2 组件和 4 屏代码合入；导入报错已由 Claude 修（`import_resources.mjs` 跳过工作台专用的嵌套文字组 `audio.dom`），`keys.adjust` 现在能导入。剩下的复验（全套测试、选章两张和设置中文超限）并进 UI-06b 第 1 步。制作方提交的 `verification.json` 是失败半截运行的结果，会清掉 30 关 SDK 记录，没有采用。
基线：`claude/inspiring-ride-zfnn4s` → 分支：`ui/UI-06a`（**不要**从 `main` 开：`main` 还是旧内容）
预计：3–4 小时；超过 5 小时还没做完就停下，把进度写进「交付」交回。
**必须在用户的 Mac 上做**：仓库里的 Godot / SDK 只有 macOS arm64 版，云端和 Linux 跑不了 Godot 测试。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-UI-06a -b ui/UI-06a origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-UI-06a
```
**交回**（二选一）：
- 能推送：`git push -u origin ui/UI-06a`
- 不能推送：`git bundle create UI-06a.bundle origin/claude/inspiring-ride-zfnn4s..ui/UI-06a`，把 `UI-06a.bundle` 交给用户

只往 `ui/UI-06a` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
Godot 游戏里的 **选章、选关、设置、暂停** 4 个界面换成用户确认的 G2 深蓝圆角样式，和工作台的参考图 `art/export/reference/<界面>.<语言>.png` 一致（中英文各一张）。G2 的公共画法做成 Godot 里的公共组件，给 UI-06b 接着用。

## 要读的（只读这些）
- `workbench/js/core/ui-common.js`：G2 组件（面板、标题条、按钮三态、选择行、光标、键帽、滑块、开关、标签）的颜色、圆角、尺寸。这是规格，照着在 Godot 里实现。
- `workbench/js/core/ui-screens-level.js`：只看 `chapters`、`levels`、`settings`、`pause` 四个界面的布局。
- `game/presentation/ui/screens/screen.gd`：只看 `_chapters`、`_levels`、`_settings`、`_pause` 和它们用到的辅助函数；`game/presentation/ui/widgets/ui_factory.gd`。
- `game/tests/ui/capture.gd`：截图怎么和参考图比。
- [docs/design/architecture.md](../design/architecture.md) 第 7 节（工作台和游戏的对应）。

## 要做的
1. **先重新导入**（参考图和文字表都换了新版）：
   ```bash
   node tools/content.mjs build
   node game/tools/import_resources.mjs import
   ```
   新文字在 `content/i18n-common/` 等新表里，导入工具会合进 `game/generated/content/i18n/`，不用手改。
2. **新建 `game/presentation/ui/widgets/g2.gd`**：G2 公共组件（照 `ui-common.js`）。颜色用调色板，不写死新颜色。
3. **改 `screen.gd` 里这 4 个界面**改用 `g2.gd`：
   - 设置：**去掉「界面风格」一行**（G2 已定，不再切换），其余 8 项保留；
   - 布局、文字位置照参考图；文字仍从文字表取，容器按文字宽度伸缩，不按像素写死文字。
4. 其他界面（大厅、提示、规则卡、对话、过关、关卡 HUD）**这包不改**，留给 UI-06b；关卡 HUD 不换（工作台的 `scene.js` HUD 没变）。
5. 已知的坑：
   - 只能用已确认的美术（`art/export/manifest.json` 里 `current_is_approved` 为 true）。G2 界面 18 项都已确认（APR-0007）。
   - `ui.screen.lobby`（6 套章节大厅皮肤）**没有确认**，不要碰大厅。
   - `screen.gd` 很长；只改这 4 个界面的函数，不要顺手整理别的代码（UI-06b 接着改同一个文件）。

验收和下面「可改的文件」清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 可改的文件
- 新建：`game/presentation/ui/widgets/g2.gd`
- `game/presentation/ui/screens/screen.gd`：只改 4 个界面的函数（可以加新的辅助函数）
- `game/tests/ui/*.gd`：可以加检查；改已有检查的预期要在交付里写明
- 生成文件（用工具生成后提交，不手改）：`game/generated/**`、`game/reports/ui-reference-report.json`、`game/reports/shots/*.png`、`game/reports/verification.json`、`content/export/*`
- 本文件的状态和「交付」

## 不能碰的文件
- 冻结区（AGENTS.md 2a）：`art/**`、`workbench/js/core/**`、`content/i18n/**`
- 规则和数据：`content/**`（除了生成的 `content/export/*`）、`game/gameplay/**`、`game/sim/**`
- 大厅和其他界面（UI-06b 做）、`docs/design/**`、`docs/status.md`

## 检查
边做边跑（只跑这些）：
```bash
tools/run-tests.sh --suites ui,ui-contracts
sh -c '. tools/godot-bin.sh && find_portitor_godot && "$PORTITOR_GODOT" --path game --display-driver macos --audio-driver Dummy --script res://tests/ui/capture.gd'   # 只跑界面截图对照，看 game/reports/shots/
```
最后跑一次：
```bash
tools/run-tests.sh            # 默认全套，全部通过
sh -c '. tools/godot-bin.sh && find_portitor_godot && "$PORTITOR_GODOT" --path game --display-driver macos --audio-driver Dummy --script res://tests/ui/capture.gd'   # 只跑界面截图对照
node tools/content.mjs check  # 0 错误
node tools/art.mjs build      # 0 bumped，确认记录 7 条
```
不要跑 `--gpu` 全套（含性能测试，很慢、占资源）。不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对、为写交付补跑命令（process.md 第 10 节）。

## 验收
- `game/reports/ui-reference-report.json` 里 chapters、levels、settings、pause 中英文 8 张：每张差异像素 ≤ 1700（约 3%，只允许字体渲染差异）；超了就写出原因。
- 打开 `game/reports/shots/settings.zh-Hans.png`：深蓝圆角面板，没有「界面风格」一行。
- 默认全套测试全部通过。

## 交付（制作方填写，不超过 40 行）
- 公共组件：G2 面板、标题条、按钮三态、选择行、光标、键帽/提示条、滑块、开关、标签、确认图标及静态章节/关卡插图；统一调色板、动态字宽，禁用字偶紧排以对应工作台逐字绘制。
- 选章：G2 卡片/页点/说明，保留真实关卡数；差异中文 1809、英文 1767，均未过 1700。
- 选关：G2 双面板、列表、状态标签、初始地图预览及完整可滚动说明；差异中文 1432、英文 1475，均通过。
- 设置：8 项，未提供界面风格切换；保留音量拖动、键盘调整；差异中文 2005（未过）、英文 1601（通过）。
- 暂停：G2 标题、图标菜单和快捷键，关卡 HUD 沿用原实现；差异中文 1278、英文 1267，均通过。
- `tools/run-tests.sh`：默认全套只运行一次，退出 1；resources 因 `translation must be a string: en/audio.dom` 失败。importer、model-export、ladder-reference-export、reference-export、godot-import 通过；UI 及后续套件未执行，不能报告全套通过。
- 最终受影响快检 `--suites ui,ui-contracts`：同一 resources 失败，Godot 导入通过；UI 套件仍未执行。
- 截图命令：16 张，退出 1；0 引擎错误、0 布局问题，3 项既有行为检查通过；目标 8 张中 5 张通过、3 张超限，未放宽阈值。
- `node tools/content.mjs check`：0 error(s)、0 warning(s)。
- `node tools/art.mjs build`：build ok，159 assets、0 bumped、100 reference renders、7 approval records。
- 测试预期：capture 新增四屏 1700 像素断言；清空样例进度，固定设置页音乐焦点、自动缩放/关网格/关全关卡，避免原存档及旧焦点污染参考；像素失败与布局问题分别记录。其他测试预期无改动。
- 技术审核：只读代码审查完成；已修复跨章节背景主题和音量输入区域同步问题。未取得全套技术验证通过，也未取得用户界面验收。
- 本机依赖：使用用户指定 zips 目录的 Godot 4.7.2；独立目录的忽略字体依赖链接到本机原目录，未提交依赖。
- 范围：仅四屏及其辅助函数、新 G2 组件、截图测试和允许的生成文件；美术构建额外改写的工作台生成数据已还原，冻结区无提交改动。
### 问题
- 导入工具/源翻译表不在本包可改范围，未绕过 `en/audio.dom` 类型错误；新文字 `keys.adjust` 未导入，中文设置底栏仍显示键名，是其超限主因。
- 选章插图局部仍有差异；第二章真实总数为 9，参考样例为 7，保留真实清单及真实页点，不按样例篡改设计数据。
- 当前阶段：已交回候选，像素及默认全套均未完全通过，不是正式完成版本；用户验收未进行。
- 下一步/执行人：整理合并方先审查候选并登记导入工具及剩余像素修复包，用户派给制作方；修复后制作方在本分支复验，全部通过后再由用户验收。进度仅记本包，遵守本包白名单未改共享进度文件。
