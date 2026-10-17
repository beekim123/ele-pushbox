# UI-06c Godot 大厅：6 套章节皮肤

状态：**已合并**（2026-10-17，bundle `c7946b2`）。默认全套 26/26 通过（含 ids）；8 张大厅截图 7 张达标，森林 1862 超 162，交 [UI-06d](UI-06d.md)：原因多半是共用噪声函数 `Hh`（`ui-kit.js`，不限位数整数）在 Godot 64 位整数下溢出。
基线：`claude/inspiring-ride-zfnn4s`（已包含 UI-06b）→ 分支：`ui/UI-06c`（**不要**从 `main` 开）
预计：3–4 小时；超过 5 小时还没做完就停下，把进度写进「交付」交回。
**必须在用户的 Mac 上做**（Godot / SDK 只有 macOS arm64 版）。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-UI-06c -b ui/UI-06c origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-UI-06c
```
**交回**（二选一）：
- 能推送：`git push -u origin ui/UI-06c`
- 不能推送：`git bundle create UI-06c.bundle origin/claude/inspiring-ride-zfnn4s..ui/UI-06c`，把 `UI-06c.bundle` 交给用户

只往 `ui/UI-06c` 提交；不往别的分支推送，也不合并别的分支。

## 目标
Godot 的大厅按当前章节换皮肤（6 套，用户 2026-10-17 确认 `ui.screen.lobby@v5`，APR-0008），和参考图 `art/export/reference/lobby.<主题>.png`（dungeon、ruins、cave、forest、sky、cosmos）以及 `lobby.zh-Hans.png`、`lobby.en.png` 一致。做完后关卡模式从大厅到过关全部是用户确认过的新界面。

## 要读的（只读这些）
- `workbench/js/core/ui-skins.js`：6 套皮肤的画法和「章节 → 皮肤」对应（文件末尾）。这是规格，照着在 Godot 里实现。
- `game/presentation/ui/screens/screen.gd`：只看 `_lobby` 和它用到的辅助函数
- `game/presentation/ui/widgets/g2.gd`：能复用的组件
- `game/tests/ui/capture.gd`

## 要做的
1. 先导入：`node tools/content.mjs build && node game/tools/import_resources.mjs import`
2. 新建 `game/presentation/ui/widgets/lobby_skins.gd`：6 套皮肤；`screen.gd` 的 `_lobby` 按当前章节选皮肤。
3. `capture.gd`：大厅按 6 个主题各截一张，和 `lobby.<主题>.png` 比；中英文各一张和 `lobby.<语言>.png` 比。只在截图测试里切章节，不改存档和关卡数据。
4. 已知的坑：
   - 通用大厅 `lobby_generic` 是给配送地图（地府、海女村）用的，不在本包（配送进 Godot 见 DLV-02）。
   - `game/reports/verification.json` 只在默认全套完整跑完时才提交；半截失败时 `git checkout -- game/reports/verification.json`。

验收和下面「可改的文件」清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 可改的文件
- 新建：`game/presentation/ui/widgets/lobby_skins.gd`
- `game/presentation/ui/screens/screen.gd`：只改 `_lobby` 和它的辅助函数
- `game/tests/ui/*.gd`：加检查、改截图清单；改已有检查的预期要在交付里写明
- 生成文件（用工具生成后提交）：`game/generated/**`、`game/reports/ui-reference-report.json`、`game/reports/shots/*.png`、`content/export/*`；`verification.json` 见上面
- 本文件的状态和「交付」

## 不能碰的文件
- 冻结区（AGENTS.md 2a）：`art/**`、`workbench/js/core/**`、`content/i18n/**`
- `content/**`（除了生成的 `content/export/*`）、`game/gameplay/**`、`game/sim/**`、`game/tools/**`
- 其他界面（UI-06a、06b 做好的）、`g2.gd` 已有组件、`docs/design/**`、`docs/status.md`

## 检查
边做边跑（只跑这些）：
```bash
tools/run-tests.sh --suites ui,ui-contracts
sh -c '. tools/godot-bin.sh && find_portitor_godot && "$PORTITOR_GODOT" --path game --display-driver macos --audio-driver Dummy --script res://tests/ui/capture.gd'   # 只跑界面截图对照
```
最后跑一次：
```bash
tools/run-tests.sh            # 默认全套，全部通过
sh -c '. tools/godot-bin.sh && find_portitor_godot && "$PORTITOR_GODOT" --path game --display-driver macos --audio-driver Dummy --script res://tests/ui/capture.gd'
node tools/content.mjs check  # 0 错误，并且仍是 "mechanisms playable 27"
node tools/art.mjs build      # 0 bumped，确认记录 8 条
# 默认全套里 ids 应该通过（2026-10-17 已修）；不通过就把 game/reports/id-checks.json 的 errors 贴进交付
```
不要跑 `--gpu` 全套。不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对、为写交付补跑命令（process.md 第 10 节）。

## 验收
- 大厅 6 个主题 + 中英文共 8 张截图，每张差异像素 ≤ 1700；超了写出原因。
- 打开 Godot 游戏：切到不同章节回大厅，皮肤跟着换。
- 默认全套测试全部通过；`content.mjs check` 仍是 `mechanisms playable 27`。

## 交付（制作方填写，不超过 40 行）
- 地牢 / S2：漂浮符文石板、发光选中标记；差异 1148 像素。
- 遗迹 / S3：祥云玉简、卷轴菜单与流苏；差异 1033 像素。
- 洞穴 / S1：晶石标题、切角面板与晶簇；差异 1639 像素。
- 森林 / S5：藤木、苔藓、叶片游标与萤光；差异 1862 像素，超过 1700 阈值 162。
- 天空 / S4：糖霜圆角、梦泡与星形游标；差异 906 像素。
- 宇宙 / S6：点阵标题、舱板、警戒条与火箭；差异 596 像素。
- 语言截图：zh-Hans 1148、en 1259 像素；8 张大厅中 7 张达标。
- 大厅按当前章节调用既有背景接口；菜单仍调用原有操作。未修改其他界面、存档或关卡数据。
- `tools/run-tests.sh`：仅运行一次默认全套，完整结束、退出 0；26 项 PASS，含 ids PASS；完整 verification.json 随交。
- 指定 `capture.gd` 命令：退出 1；24 张截图、layout_issues 0、reference_issues 1（仅森林）；原有 16 张其他界面对照通过。
- 截图内新增检查：6 套章节/皮肤映射、6 套菜单键盘焦点、存档不变，全部通过；只用内存中的章节夹具。
- `node tools/content.mjs check`：0 error(s)、0 warning(s)，mechanisms playable 27。
- `node tools/art.mjs build`：159 assets、0 bumped、100 reference renders、8 approval records；正式语言排版 0 issue。
- 已有测试预期改动：无；新增大厅截图清单，原有断言及 1700 像素阈值均保留。
- 问题：森林木纹/苔藓噪声及局部边框尚未完全对齐；当前使用 Godot 的确定性 h32，不能视为与规格共用图元 H 完全等价。
- 问题：本包可读文件未列出该共用图元的定义；本次保留真实失败数据，未扩读文件或改设计来绕过验收。
- 当前阶段：制作候选交付；森林截图验收未通过，尚未完成技术审核、用户验收或正式合并。
- 下一步/执行人：Claude 整理合并方核对范围与交付问题，退回本包并明确共用图元可读范围；制作方校准森林后，由 Claude 再审合并。
