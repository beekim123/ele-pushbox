# UI-06a Godot 换 G2 界面（一）：公共组件 + 选章、选关、设置、暂停

状态：待派（2026-10-17；用户已确认 G2 界面 APR-0007）
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
- `g2.gd` 有哪些组件（一行）
- 4 个界面各一句，加中英文差异像素数
- 上面「最后跑一次」各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
