# ART-02c 糖果王国美术③：怪物、零食、货物和机关外观（8 项）

状态：待派（DSN-05 合并后）
基线：`claude/inspiring-ride-zfnn4s`（DSN-05 合并后）→ 分支：`art/ART-02c`（**不要**从 `main` 开：用户决定先不合进 main）
预计：3 小时；超过 4 小时还没做完就停下，把进度写进「交付」交回。
和 ART-02a、ART-02b、DLV-08 互不依赖，可以同时做（DLV-08 在资产没合并时画占位）。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-ART-02c -b art/ART-02c origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-ART-02c
```
**交回**（二选一）：
- 能推送：`git push -u origin art/ART-02c`
- 不能推送：`git bundle create ART-02c.bundle origin/claude/inspiring-ride-zfnn4s..art/ART-02c`，把 `ART-02c.bundle` 交给用户

只往 `art/ART-02c` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
做出糖果王国的 2 种怪物、零食图标、2 种新货物（含损坏状态）和软糖 / 烤炉口 / 热气在这张图里的外观，共 8 项第 1 版资产（status `review`）。做完在工作台「资产与动画」页能看到。

## 要读的（只读这些）
- [delivery-candy.md](../design/delivery-candy.md) 第 1 节「取材注意」、第 2 节（货物）、第 3 节（怪物）、第 5 节（零食）、第 6 节里 ART-02c 的 8 行、第 7 节第 12 条
- [art-direction.md](../design/art-direction.md)：调色板、尺寸规定
- [art-pipeline.md](../design/art-pipeline.md)：新资产怎么登记、版本和确认记录
- 济州的同类资产（`monster.dokkaebi`、`item.snack_jeju`、`cargo.tangerine`、`mech.jeju_seesaw`、`fx.jeju_gust`）：照它们的尺寸、动作和登记方式

## 要做的
1. 新资产 8 项（尺寸、动作照第 6 节）：`monster.ant_army`、`monster.gingerbread`、`item.snack_candy`、`cargo.chocolate`（`default`、`melted`）、`cargo.pudding`（`default`、`collapsed`）、`mech.candy_jelly`（`idle`、`squash`、`launch`）、`mech.candy_oven_vent`（`off`、`on`）、`fx.candy_heat`（`idle`、`blow`）。
2. 已有的 `item.snack` 不能改，另建 `item.snack_candy`；冰淇淋、信件沿用已有的货物图，不重画。
3. 软糖要和地面一样平时也一眼认出来：一整格，顶边就是格子顶边，颜色（葡萄紫 `C`）和饼干、糖霜、规则材料都分得开。烤炉口是嵌在地里的铁格栅，熄着和点着差别明显。
4. 姜饼人、蚂蚁照「取材注意」：可爱，不画碎掉、被咬、被吃，蚂蚁不画写实特写。
5. 机关外观只给糖果配送用：**不**登记进 `mechanisms.json`（第 7 节第 12 条，等用户定）；接进配送画面是 DLV-08 的事，本包只做资产。
6. 对照图放 `docs/packages/ART-02c/`：全部 8 项的总览一张，加一张软糖、烤炉口放在饼干地面上的样子（地形用占位色即可，不依赖 ART-02a）。
7. 共同规定：
- 新资产全部是第 1 版，status `review`；**不能自己确认**（确认记录条数不变），等用户看。
- `workbench/index.html`、`tools/art.mjs` 只追加，不改已有的行。新字体文件（如果有）要同时进三处字体清单（process.md 第 10 节）。
- 调色板 ENDESGA 32（只用 art-direction 里的代码），`z` 描边，面朝右画；人物、动物、怪物 8 fps 以内，装饰 4 fps 以内（特效除外）。
- 已确认的资产不能改；要改就另做新编号，写进交付。

## 可改的文件
- 新建：这 8 项资产在 `art/source/` 下的源文件（写法照 art-pipeline.md）；`docs/packages/ART-02c/*.png`
- `workbench/index.html`、`tools/art.mjs`：只追加（需要时）
- 生成文件（用工具生成后提交，不手改）：`tools/art.mjs build` 生成的 `art/export/*`、`art/history/*`，`content/export/*`、`workbench/data/*`
- 本文件的状态和「交付」
- （清单之外一律不改。验收和这个清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过）

## 不能碰的文件
- `art/approvals.json`（确认记录：不能自己确认）
- AGENTS.md 2a 的冻结区：已确认的资产（包括 `item.snack`、已有的货物图）、`workbench/js/core/**`、`content/i18n/**`
- `content/catalog/**`（包括 `mechanisms.json`）、ART-02a、ART-02b 的资产、`tests/**`、`game/**`
- `docs/status.md`

## 验收（运行什么 → 看到什么）
- `node tools/art.mjs build` → 只多了本包的 8 项（第 1 版、`review`）；0 bumped；确认记录条数和改前一样
- `node tools/content.mjs build && node tools/content.mjs check` → 0 错误、0 警告
- 浏览器打开 `workbench/index.html#assets/mech.candy_jelly`、`#assets/monster.gingerbread` 等 → 每个动作都能播放

## 检查
边做边跑（只跑这些）：
```bash
node tools/art.mjs build
```
最后跑一次：
```bash
node tools/content.mjs build && node tools/content.mjs check   # 0 错误、0 警告
node tools/art.mjs build                                       # 只多本包 8 项；0 bumped；确认记录条数不变
node --test tests/*.test.mjs
PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/local/bin/chromium node tests/workbench.e2e.cjs   # Linux 要设这个变量，macOS 不用
```
不要做的：逐个算文件哈希、复制仓库做试验、逐帧比对、为写交付补跑命令（见 process.md 第 10 节）。

## 交付（制作方填写，不超过 40 行）
- 做了什么（每项一句）
- 检查命令各一行结果
- 改了哪条测试的预期、为什么（没有写"无"）
- 遗留问题（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
