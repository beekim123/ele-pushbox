# UI-06b Godot 换 G2 界面（二）：补完 UI-06a + 提示、规则卡、对话、过关

状态：待派（2026-10-17；UI-06a 已合并，部分通过，剩下的复验在本包第 1 步）
基线：`claude/inspiring-ride-zfnn4s`（已包含 UI-06a 和导入工具修正）→ 分支：`ui/UI-06b`（**不要**从 `main` 开）
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
1. 把 UI-06a 没过的部分补完：默认全套测试通过；选章、设置的截图差异降到 1700 像素以内。
2. Godot 里的 **提示、规则卡、对话、过关** 4 个界面换成 G2，和参考图一致。
大厅（6 套章节皮肤）不在本包，见 UI-06c。

## 要读的（只读这些）
- [UI-06a.md](UI-06a.md) 的状态行和「交付」：上次哪里没过
- `game/presentation/ui/widgets/g2.gd`（UI-06a 做的组件）
- `workbench/js/core/ui-screens-level.js`：只看 `hint`、`rulecard`、`dialogue`、`complete`
- `game/presentation/ui/screens/screen.gd`：只看提示、规则卡、对话、过关相关函数；`game/presentation/ui/widgets/bubble.gd`
- `game/tests/ui/capture.gd`

## 要做的
1. **补完 UI-06a**：
   - 先导入：`node tools/content.mjs build && node game/tools/import_resources.mjs import`。上次的 `translation must be a string: en/audio.dom` 已由 Claude 修好；设置底栏的 `keys.adjust` 现在能导入，应该会正常显示。
   - 跑默认全套 `tools/run-tests.sh`，修好本包范围内的失败。
   - 选章：参考图用的是样例数据（第二章 7 关），游戏是真实数据（9 关）。在 `capture.gd` 里像已有的 `ChapterAvailabilityFixture` 那样，**只在截图测试里**用和参考图一样的样例数，不改关卡数据。
   - 重跑截图，选章中英文、设置中文降到 1700 以内。
2. **4 个界面换 G2**：改 `screen.gd` 里提示、规则卡、对话、过关，用 `g2.gd`；对话气泡改 `bubble.gd`（G2 多行说话泡、心里话泡）。
3. `capture.gd` 的截图清单加上 `dialogue`。
4. 已知的坑：
   - 只用已确认的美术；不改 UI-06a 做好的 4 个界面的布局（第 1 步的修正除外），`g2.gd` 缺组件只在末尾加。
   - **`game/reports/verification.json` 只在默认全套完整跑完时才提交**。半截失败的运行会清掉 30 关的 SDK 记录（上次就是这样），这时不要提交这个文件：`git checkout -- game/reports/verification.json`。

验收和下面「可改的文件」清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 可改的文件
- `game/presentation/ui/screens/screen.gd`：只改选章、设置（第 1 步）和提示、规则卡、对话、过关的函数
- `game/presentation/ui/widgets/bubble.gd`；`g2.gd`（只在末尾加组件）
- `game/tests/ui/*.gd`：加检查、改截图清单和样例；改已有检查的预期要在交付里写明
- 生成文件（用工具生成后提交）：`game/generated/**`、`game/reports/ui-reference-report.json`、`game/reports/shots/*.png`、`content/export/*`；`game/reports/verification.json` 见上面第 4 步
- 本文件的状态和「交付」

## 不能碰的文件
- 冻结区（AGENTS.md 2a）：`art/**`、`workbench/js/core/**`、`content/i18n/**`
- `content/**`（除了生成的 `content/export/*`）、`game/gameplay/**`、`game/sim/**`、`game/tools/**`
- 大厅 `_lobby`（UI-06c 做）、关卡 HUD、配送界面（DLV-02）、`docs/design/**`、`docs/status.md`

## 检查
边做边跑（只跑这些）：
```bash
tools/run-tests.sh --suites ui,ui-contracts,ui-interactions
sh -c '. tools/godot-bin.sh && find_portitor_godot && "$PORTITOR_GODOT" --path game --display-driver macos --audio-driver Dummy --script res://tests/ui/capture.gd'   # 只跑界面截图对照，看 game/reports/shots/
```
最后跑一次：
```bash
tools/run-tests.sh            # 默认全套，全部通过
sh -c '. tools/godot-bin.sh && find_portitor_godot && "$PORTITOR_GODOT" --path game --display-driver macos --audio-driver Dummy --script res://tests/ui/capture.gd'
node tools/content.mjs check  # 0 错误，并且仍是 "mechanisms playable 27"
node tools/art.mjs build      # 0 bumped，确认记录 8 条
```
不要跑 `--gpu` 全套（含性能测试，很慢、占资源）。不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对、为写交付补跑命令（process.md 第 10 节）。

## 验收
- `ui-reference-report.json` 里 chapters、levels、settings、pause、hint、rulecard、dialogue、complete 中英文 16 张：每张差异像素 ≤ 1700；超了写出原因。
- `tools/run-tests.sh` 默认全套全部通过。
- `node tools/content.mjs check` 仍显示 `mechanisms playable 27`（说明 30 关 SDK 记录还在）。

## 交付（制作方填写，不超过 40 行）
- 第 1 步：全套结果、选章 / 设置的新差异像素数
- 4 个界面各一句，加中英文差异像素数
- 上面「最后跑一次」各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
