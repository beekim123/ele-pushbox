# UI-11b 设置里选大厅皮肤（Godot）

状态：**等 UI-11a 合并、用户确认设置页 v7 后再派**
基线：`claude/inspiring-ride-zfnn4s` → 分支：`ui/UI-11b`（**不要**从 `main` 开：用户决定先不合进 main）
预计：2–3 小时；超过 4 小时 还没做完就停下，把进度写进「交付」交回。
**必须在用户的 Mac 上做**（Godot / SDK 只有 macOS arm64 版）。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-UI-11b -b ui/UI-11b origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-UI-11b
```
**交回**（二选一）：
- 能推送：`git push -u origin ui/UI-11b`
- 不能推送：`git bundle create UI-11b.bundle origin/claude/inspiring-ride-zfnn4s..ui/UI-11b`，把 `UI-11b.bundle` 交给用户

只往 `ui/UI-11b` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
Godot 里：设置页有「大厅皮肤」一行（7 个选项，默认 S2 漂浮符文），选的结果存进存档；大厅显示选中那套的整张画面（皮肤 + 对应背景），不再跟着当前章节换。

## 要读的（只读这些）
- [UI-11a.md](UI-11a.md) 的目标和「交付」
- `docs/design/ui-style.md` 第 2 节（UI-11a 改过的）
- `game/presentation/ui/screens/screen.gd`：只看 `_settings`、`_lobby`
- `game/presentation/ui/widgets/lobby_skins.gd` 开头（皮肤怎么按主题选）
- `game/app/autoload/settings.gd`（设置怎么存）
- `game/tests/ui/capture.gd`

## 要做的
1. 先导入：`node tools/content.mjs build && node game/tools/import_resources.mjs import`
2. `settings.gd` 加 `lobby_skin`（值是 `S1`…`S6` 或 `generic`，默认 `S2`），读写存档；旧存档没有这一项时用默认值。
3. `screen.gd` 的 `_settings` 加这一行（照参考图 `art/export/reference/settings.<语言>.png` v7）；`_lobby` 按 `lobby_skin` 选皮肤和背景，`generic` 用通用大厅（画法照 `workbench/js/core/ui-screens-result.js` 的 `lobby_generic`）。
4. `capture.gd`：设置页截图对照 v7 参考图；大厅 6 套 + 通用照旧各截一张（改成用 `lobby_skin` 切，不再切章节）。加一条检查：改设置 → 回大厅 → 皮肤变了；存档重读后还在。
5. `game/reports/verification.json` 只在默认全套完整跑完时才提交；没跑完就 `git checkout -- game/reports/verification.json`。

验收和下面「可改的文件」清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 可改的文件
- `game/app/autoload/settings.gd`、`game/presentation/ui/screens/screen.gd`（只改 `_settings`、`_lobby` 和它们的辅助函数）、`game/presentation/ui/widgets/lobby_skins.gd`（只加按设置选皮肤的入口）
- `game/tests/ui/*.gd`
- 生成文件（用工具生成后提交）：`game/generated/**`、`game/reports/ui-reference-report.json`、`game/reports/shots/*.png`、`content/export/*`；`verification.json` 见上面
- 本文件的状态和「交付」

## 不能碰的文件
- 冻结区（AGENTS.md 2a）、`content/**`（除了生成的 `content/export/*`）、`game/gameplay/**`、`game/tools/**`、其他界面的函数、`docs/design/**`、`docs/status.md`

## 检查
边做边跑：
```bash
tools/run-tests.sh --suites ui,ui-contracts
sh -c '. tools/godot-bin.sh && find_portitor_godot && "$PORTITOR_GODOT" --path game --display-driver macos --audio-driver Dummy --script res://tests/ui/capture.gd'   # 只跑界面截图对照
```
最后跑一次：
```bash
tools/run-tests.sh            # 默认全套，全部通过（含 ids）
sh -c '. tools/godot-bin.sh && find_portitor_godot && "$PORTITOR_GODOT" --path game --display-driver macos --audio-driver Dummy --script res://tests/ui/capture.gd'
node tools/content.mjs check  # 0 错误，仍是 "mechanisms playable 27"
```
不要跑 `--gpu` 全套。不要做的：逐个算文件哈希、复制仓库做试验、为写交付补跑命令（process.md 第 10 节）。

## 验收
- 截图报告全部 ≤ 1700 像素，`reference_issues` 0（含设置页 v7、大厅 7 张）。
- 打开 Godot：设置里切到「藤木萤光」→ 回大厅是森林那套；重开游戏仍是它。

## 交付（制作方填写，不超过 40 行）
- 做了什么（每项一句）
- 检查命令各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
