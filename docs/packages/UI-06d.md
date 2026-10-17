# UI-06d Godot 大厅：森林皮肤对齐（UI-06c 收尾）

状态：待派（2026-10-17，UI-06c 已合并，只差森林）
基线：`claude/inspiring-ride-zfnn4s`（已包含 UI-06c）→ 分支：`ui/UI-06d`（**不要**从 `main` 开）
预计：1–2 小时；超过 3 小时还没做完就停下，把进度写进「交付」交回。
**必须在用户的 Mac 上做**（Godot / SDK 只有 macOS arm64 版）。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-UI-06d -b ui/UI-06d origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-UI-06d
```
**交回**（二选一）：
- 能推送：`git push -u origin ui/UI-06d`
- 不能推送：`git bundle create UI-06d.bundle origin/claude/inspiring-ride-zfnn4s..ui/UI-06d`，把 `UI-06d.bundle` 交给用户

只往 `ui/UI-06d` 提交；不往别的分支推送，也不合并别的分支。

## 目标
Godot 大厅的森林皮肤（S5）截图和 `art/export/reference/lobby.forest.png` 的差异从 1862 降到 ≤ 1700 像素。其他 5 套皮肤和中英文两张不能变差。

## 要读的（只读这些）
- [UI-06c.md](UI-06c.md) 的「交付」：上次哪里没对齐
- `workbench/js/core/ui-kit.js` 第 24–30 行：共用的随机图元 `Hh(x, y, s)`（木纹、苔藓、萤光的噪声都用它）。上次包里没列这个文件。
- `workbench/js/core/ui-skins.js` 第 423 行起的 S5（藤木萤光），只看 `S5` 和它用到的辅助函数
- `game/presentation/ui/widgets/lobby_skins.gd`：只看森林相关部分

## 要做的
1. **对齐 `Hh`**：`Hh` 用的是不限位数的整数（JS `BigInt`，照 Python 原稿），中间结果会超过 64 位。Godot 的 `int` 是 64 位，直接照抄会溢出，结果不一样。改成和 `Hh` 逐值相同的实现（例如把乘法拆开、只保留最后 `% 1000` 需要的部分），用同一个函数替换 `lobby_skins.gd` 里现在的 `h32`。
2. 加一个小测试：取几十个 `(x, y, s)`，和 `Hh` 的结果比（期望值在 Node 里用 `ui-kit.js` 算出来写进测试）。
3. 再对森林的边框和局部图元，重跑截图。
4. 已知的坑：
   - 6 套皮肤都在用这个函数，换掉后其他 5 套的差异可能也会变，要一起看，不能变差；
   - `game/reports/verification.json` 只在默认全套完整跑完时才提交。

验收和下面「可改的文件」清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 可改的文件
- `game/presentation/ui/widgets/lobby_skins.gd`
- `game/tests/ui/*.gd`：只加第 2 步的测试
- 生成文件（用工具生成后提交）：`game/generated/**`、`game/reports/ui-reference-report.json`、`game/reports/shots/*.png`、`content/export/*`；`verification.json` 见上面
- 本文件的状态和「交付」

## 不能碰的文件
- 冻结区（AGENTS.md 2a）：`art/**`、`workbench/js/core/**`（只读）、`content/i18n/**`
- `screen.gd`、`g2.gd` 和其他界面、`content/**`、`game/gameplay/**`、`game/tools/**`、`docs/design/**`、`docs/status.md`

## 检查
边做边跑（只跑这些）：
```bash
sh -c '. tools/godot-bin.sh && find_portitor_godot && "$PORTITOR_GODOT" --path game --display-driver macos --audio-driver Dummy --script res://tests/ui/capture.gd'   # 只跑界面截图对照
```
最后跑一次：
```bash
tools/run-tests.sh            # 默认全套，全部通过（含 ids）
sh -c '. tools/godot-bin.sh && find_portitor_godot && "$PORTITOR_GODOT" --path game --display-driver macos --audio-driver Dummy --script res://tests/ui/capture.gd'
node tools/content.mjs check  # 0 错误，仍是 "mechanisms playable 27"
```
不要跑 `--gpu` 全套。不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对、为写交付补跑命令（process.md 第 10 节）。

## 验收
- 截图报告里 24 张全部 ≤ 1700 像素（大厅 6 套 + 中英文 2 张，加原来 16 张界面），`reference_issues` 为 0。
- 默认全套全部通过。

## 交付（制作方填写，不超过 40 行）
- `Hh` 怎么对齐的、测试比了几个值
- 6 套皮肤和中英文新的差异像素数
- 上面「最后跑一次」各一行结果
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
