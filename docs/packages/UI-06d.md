# UI-06d Godot 大厅：森林皮肤对齐（UI-06c 收尾）

状态：**已合并**（2026-10-17，`ui/UI-06d` @ `8a64cd9`）。Claude 核对：64 组 `Hh` 期望值和 `ui-kit.js` 逐个相同；24 张截图全部 ≤1700。
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
- `Hh`：用 uint32 分段保存初始有符号 96 位值和乘法进位，以 128 位分段完成异或/右移，再求 `% 1000`，不依赖溢出的 `h32`。
- 在 `capture.gd` 新增 64 组固定期望值，直接由 Node 执行 `ui-kit.js:24–30` 的 `Hh` 生成；含界面坐标、负数、int32/int64 边界。旧实现 63/64 失败，新实现 64/64 通过。未删改既有断言或阈值。
- 六套皮肤差异（像素）：地牢 1148→633；遗迹 1033→1033；洞穴 1639→1639；森林 1862→717；天空 906→906；宇宙 596→596。
- 中英文差异（像素）：zh-Hans 1148→633；en 1259→715；其他五套及两种语言均未变差。
- 森林边框与局部图元已对照截图；剩余差异：标题 0、章节 156、菜单 339、按键 158、背景 64、地面 0；无需追加几何或设计变更即达到 ≤1700。
- `tools/run-tests.sh`：默认全套完整结束、退出 0，26 项 PASS（含 ids、SDK、levels、chapters）；完整 `verification.json` 随交。
- 全套启动准备曾因本次 SDK 符号链接导致 cp 同文件错误，未进入测试；移除链接后按标准脚本准备并重试成功。未跑 `--gpu` 全套。
- 指定 `capture.gd`：退出 0，captures 24、layout_issues 0、reference_issues 0；24 张全部 ≤1700，Hh 64/64 通过。
- `node tools/content.mjs check`：退出 0；0 error(s)、0 warning(s)，mechanisms playable 27。
- 运行环境：本机 Godot 4.7.2；独立目录补齐已有 SDK、字体和导入缓存。全套额外生成的非允许报告已还原，冻结区未修改。
- 问题：截图日志仍有大厅文字边界 WARNING，但报告 layout_issues 为 0；本包未越界修改 screen.gd/G2，交整理合并方判断是否另立包。
- 当前阶段：制作候选，包内自动验收通过；尚未完成整理合并方技术审核、用户验收或正式合并，美术确认状态不变。
- 下一步/执行人：用户将 ui/UI-06d 交给 Claude 整理合并聊天；Claude 按流程审核范围与上述问题后合并并更新项目进度。用户验收由用户执行。
