# UI-06b Godot 换 G2 界面（二）：提示、规则卡、对话、过关 + 大厅

状态：**等 UI-06a 合并后再派**（要用 UI-06a 做的 `g2.gd`，并且改同一个 `screen.gd`）
基线：`claude/inspiring-ride-zfnn4s`（已包含 UI-06a）→ 分支：`ui/UI-06b`（**不要**从 `main` 开）
预计：3–4 小时；超过 5 小时还没做完就停下，把进度写进「交付」交回。
**必须在用户的 Mac 上做**（Godot / SDK 只有 macOS arm64 版）。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-UI-06b -b ui/UI-06b origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-UI-06b
```
**交回**（二选一）：
- 能推送：`git push -u origin ui/UI-06b`
- 不能推送：`git bundle create UI-06b.bundle origin/claude/inspiring-ride-zfnn4s..ui/UI-06b`，把 `UI-06b.bundle` 交给用户

只往 `ui/UI-06b` 提交；不往别的分支推送，也不合并别的分支。

## 目标
Godot 里的 **提示、规则卡、对话、过关** 4 个界面换成 G2，和参考图一致；**大厅**换成已确认的通用大厅 `ui.screen.lobby_generic`。做完后关卡模式从大厅到过关的所有界面都是 G2。

## 要读的（只读这些）
- `game/presentation/ui/widgets/g2.gd`（UI-06a 做的组件）
- `workbench/js/core/ui-screens-level.js`：只看 `hint`、`rulecard`、`dialogue`、`complete`
- `workbench/js/core/ui-screens-result.js`：只看通用大厅 `lobby_generic`
- `game/presentation/ui/screens/screen.gd`：只看 `_lobby`、`_hint`、规则卡、对话、过关相关函数；`game/presentation/ui/widgets/bubble.gd`
- `game/tests/ui/capture.gd`

## 要做的
1. 先重新导入：`node tools/content.mjs build && node game/tools/import_resources.mjs import`
2. 改 `screen.gd` 里提示、规则卡、对话、过关 4 个界面，用 `g2.gd`；对话气泡改 `bubble.gd`（G2 多行说话泡、心里话泡）。
3. **大厅**：用通用大厅 `ui.screen.lobby_generic`（地府背景；关卡模式 / 配送 / 设置 / 退出 + 金币）。
   - 6 套按章节换的大厅皮肤 `ui.screen.lobby@v5` **用户还没确认**，Godot 不能用；等用户确认后另开小包换回按章节换皮肤。
4. `capture.gd` 的截图清单加上 `dialogue`，大厅的参考图改成 `lobby_generic`。
5. 已知的坑：只用已确认的美术；不改 UI-06a 做好的 4 个界面和 `g2.gd` 的已有组件（缺组件可以在 `g2.gd` 末尾加）。

验收和下面「可改的文件」清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 可改的文件
- `game/presentation/ui/screens/screen.gd`：只改上面 5 个界面的函数
- `game/presentation/ui/widgets/bubble.gd`；`g2.gd`（只在末尾加组件）
- `game/tests/ui/*.gd`：加检查、改截图清单；改已有检查的预期要在交付里写明
- 生成文件（用工具生成后提交）：`game/generated/**`、`game/reports/ui-reference-report.json`、`game/reports/shots/*.png`、`game/reports/verification.json`、`content/export/*`
- 本文件的状态和「交付」

## 不能碰的文件
- 冻结区（AGENTS.md 2a）：`art/**`、`workbench/js/core/**`、`content/i18n/**`
- `content/**`（除了生成的 `content/export/*`）、`game/gameplay/**`、`game/sim/**`
- 关卡 HUD、配送界面（配送 v2 还没进 Godot，见 DLV-02）、`docs/design/**`、`docs/status.md`

## 检查
边做边跑（只跑这些）：
```bash
tools/run-tests.sh --suites ui,ui-contracts,ui-interactions
sh -c '. tools/godot-bin.sh && find_portitor_godot && "$PORTITOR_GODOT" --path game --display-driver macos --audio-driver Dummy --script res://tests/ui/capture.gd'   # 只跑界面截图对照
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
- `ui-reference-report.json` 里 hint、rulecard、dialogue、complete、lobby_generic 中英文 10 张：每张差异像素 ≤ 1700（只允许字体渲染差异）；超了写出原因。
- 打开 Godot 游戏：大厅 → 选章 → 选关 → 进关 → 暂停 / 提示 → 过关，全程是 G2 样式，没有占位图。
- 默认全套测试全部通过。

## 交付（制作方填写，不超过 40 行）
- 5 个界面各一句，加中英文差异像素数
- 上面「最后跑一次」各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
