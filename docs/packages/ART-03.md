# ART-03 关卡模式 6 种机关的美术（去掉占位方块）

状态：待派（2026-10-17，用户：“占位方块，没有美术就分包出去做”）
基线：`claude/inspiring-ride-zfnn4s` → 分支：`art/ART-03`（**不要**从 `main` 开：用户决定先不合进 main）
预计：3 小时；超过 4 小时 还没做完就停下，把进度写进「交付」交回。
不用 Mac。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-ART-03 -b art/ART-03 origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-ART-03
```
**交回**（二选一）：
- 能推送：`git push -u origin art/ART-03`
- 不能推送：`git bundle create ART-03.bundle origin/claude/inspiring-ride-zfnn4s..art/ART-03`，把 `ART-03.bundle` 交给用户

只往 `art/ART-03` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
关卡模式里有 6 种机关**从来没画过美术**，Godot 里画成问号方块：矿车、灯照显形、套娃箱、弹跳蘑菇、跷跷板、阵风。用到它们的 11 关：Q07、Q08、Q09、Q10、E02、E05、E06、F08、G08、G09、G10。这一包把它们画出来（第 1 版，等用户确认）。确认后由 LV-13 在 Godot 里换掉方块。

## 要读的（只读这些）
- `workbench/js/core/mech/` 下 `mine_cart.js`、`lantern_reveal.js`、`nested_box.js`、`bounce.js`、`seesaw.js`、`gust.js`：只看开头的说明，知道它们怎么动
- `content/levels/` 下上面 11 关的规格：只看用到这 6 种机关的那几行（`devices`），知道有哪些状态
- 照着写：`art/source/mechanism/mech.bridge.json`、`mech.lift.json`、`mech.vine.json`（精灵资产的格式、动作写法）
- [art-direction.md](../design/art-direction.md)：调色板、尺寸、可读性（第 8 节）
- 参考（不能改、不能直接复用）：济州配送的 `mech.jeju_seesaw`、`fx.jeju_gust`，看别人怎么画过跷跷板和阵风

## 要做的
1. 在 `art/source/mechanism/`（阵风放 `art/source/fx/`）新建精灵资产，第 1 版、`stage: review`，16×16 一格（多格的照 `mech.lift` 的写法）。建议清单（不超过 8 项，有更好的拆法写进交付）：
   - `mech.mine_cart` 矿车：静止、滑行；`mech.cart_track` 轨道：直段、端头
   - `mech.lantern_plank` 灯照显形的幽灵木板：暗（不能站，半透明虚线）、亮（能站）
   - `obj.crate_nested` 套娃箱：外层、中层、内层三种大小（照木箱 `obj.crate_wood` 的风格，一眼看出是"箱子里还有箱子"）
   - `mech.bounce_mushroom` 弹跳蘑菇：静止、被压扁、弹起
   - `mech.seesaw` 跷跷板：左低、平、右低
   - `fx.gust` 阵风：风向线条（向左 / 向右），每 2–3 帧循环
2. 风格：要能放进 6 个章节主题里都不突兀（关卡分布在不同章节）；可读性优先，状态之间一眼分得清。
3. `content/catalog/mechanisms.json`：只给这 6 个机关的 `assets` 填上新资产编号，别的字段不动。
4. 对照图放 `docs/packages/ART-03/`：一张全部资产总览；一张"模拟关卡"——挑 G08（弹跳蘑菇）和 Q07（矿车）各一个画面，把新资产摆进去看效果（可以用临时脚本出图，脚本不提交）。

验收和下面「可改的文件」清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 可改的文件
- 新建：`art/source/mechanism/` 和 `art/source/fx/` 下上面列的资产；`docs/packages/ART-03/**`（对照图）
- `content/catalog/mechanisms.json`：只改这 6 个机关的 `assets`
- 生成文件（用工具生成后提交）：`art/export/**`、`content/export/*`、`workbench/data/*`
- 本文件的状态和「交付」

## 不能碰的文件
- 冻结区（AGENTS.md 2a）：已有的 `art/source/**`、`art/approvals.json`、`workbench/js/core/**`（包括 `scene.js`）、`content/i18n/**`
- 关卡规格 `content/levels/**`、`game/**`、`docs/status.md`
- 工作台关卡页和 Godot 里的画法（LV-13 做）

## 检查
边做边跑：`node tools/art.mjs build`，在工作台「资产与动画」页看动作
最后跑一次：
```bash
node tools/content.mjs check   # 0 错误
node tools/art.mjs build       # 0 bumped，只新增这几项，确认记录 8 条
node tools/art.mjs verify      # ok
node --test tests/*.test.mjs
```
不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对、为写交付补跑命令（process.md 第 10 节）。

## 验收
- 工作台「美术 › 确认」页能看到这几项新资产；「资产与动画」页每个动作都能播放。
- `docs/packages/ART-03/` 有总览和两张模拟关卡图。

## 交付（制作方填写，不超过 40 行）
- 做了什么（每项一句）
- 检查命令各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
