# DSN-05 第五张配送地图「糖果王国」：设计（只写设计和后续工作包）

状态：待派（2026-10-17，用户选定："雪地可以，另一个我想做糖果"）
基线：`claude/inspiring-ride-zfnn4s` → 分支：`dsn/DSN-05`（**不要**从 `main` 开：用户决定先不合进 main）
预计：3 小时；超过 4 小时还没做完就停下，把进度写进「交付」交回。
可以和 DSN-04（极地雪村） 同时做：两包都往设计目录里加条目，只动自己地图的条目，合并冲突由 Claude 处理。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-DSN-05 -b dsn/DSN-05 origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-DSN-05
```
**交回**（二选一）：
- 能推送：`git push -u origin dsn/DSN-05`
- 不能推送：`git bundle create DSN-05.bundle origin/claude/inspiring-ride-zfnn4s..dsn/DSN-05`，把 `DSN-05.bundle` 交给用户

只往 `dsn/DSN-05` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
写出配送模式新地图「糖果王国」（地区 id `candy`，地图 id `candy_1`）的**完整设计**，并把美术和房间拆成能直接派的小包。
**这一包只写文档和设计目录**：不画美术、不写代码、不做房间。（济州那次设计 + 美术放一个包，太大，做到后面出错，所以这次拆开。）

## 用户的要求
1. **明亮、开阔**：粉、薄荷绿、奶油黄的糖果色，饼干地面、奶油云、棒棒糖树、远处的蛋糕城堡。明亮可爱但不刺眼（art-direction 的调色板），不要大面积高饱和。
2. **不圈住**：照 [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 8.1、8.3 节：`top_edge: "sky"`，地形从下往上长，上面大部分是天空，多用 2×1 宽房间，边界画成自然物。
3. **专属机制**：以软糖弹跳为主：踩上去会被弹高、箱子落上去会弹起；可配合巧克力河（液体，照水的规则：箱子会浮 / 沉）、糖块遇热融化。
   - 优先用关卡模式里已经有的机制（`bounce`、`melt`）。它们在 `workbench/js/core/mech/` 有关卡模式的实现，但**配送 v2 的回合规则（`rooms2.js`）还不支持**，所以要写一个规则支持包（照 [DLV-05](DLV-05.md) 给跷跷板 / 阵风做的那样）。
   - 不发明需要新物理的机制。worlds.md 表里写的"寒冷值"这类新系统**不做**。
4. 配送 v2 的规则全部照用：先教后用、每间房只教或只用一件事、怪物不进解谜区、必需机制、不靠摔、提示和解法一致。

## 要读的（只读这些）
- [delivery-jeju.md](../design/delivery-jeju.md)：上一张地图，**照它的 7 节结构写**
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 第 3–6 节、第 8 节
- [worlds.md](../design/worlds.md) 第 2 节、第 3 节地区表里「糖果王国」那一行
- [art-direction.md](../design/art-direction.md)：只看调色板和尺寸规定
- `content/catalog/worlds.json` 的 `jeju` 和 `candy`、`slices.json` 的 `jeju_1`：数据怎么写
- `workbench/js/core/mech/` 下 `bounce`、`melt` 的文件：只看开头的说明，知道规则是什么

## 要做的
1. **新文档 `docs/design/delivery-candy.md`**，照 `delivery-jeju.md` 的 7 节写：
   1. 主题与画风：配色（用调色板代码）、地形图案、背景、装饰；写清和石牢、地府、海女村怎么区分。
   2. 收件人 4 位、货物 3–4 种：稀有度、规则、喜欢什么、住哪间收件人之家，`cargo_only` 写清。worlds.md 的候选是糖果公主、小孩；再补两位，例如面包师、冰淇淋车老板。货物要有怕热会化的（例如冰淇淋、巧克力）。
   3. 怪物 2 种：行为、怎么对付（推、压、困）、出现在哪。worlds.md 的候选是蚂蚁大军、姜饼人。蚂蚁可以做成"抢货物里的糖"（照海鸥抢东西的写法）。
   4. 房间表 12–13 间：名字、角色、大小、关键想法 → 变化、needs / teaches / requires、怪物、出入口；`layout.sequence` 和地图方向。**分成"普通房"和"机关房"两组**（后面分两个包做）。
   5. 提示动物：一只地上走的（收零食）+ 一只会飞的（只带路），零食在这张图的包装。不能和怪物混淆。
   6. 美术清单：全部候选（编号、尺寸、动作）。**按下面第 3 步分成 3 批，每批不超过 8 项。**
   7. 待定问题：每个 2–3 个选项和好坏，写明这次先按哪个做。
2. **设计目录**（只动 `candy` 的条目，新条目加在各自数组末尾）：
   - `worlds.json` 的 `candy`：补齐 `theme`、`hint_fauna`、`ambient_exclude`、`status`，照 `jeju`；
   - `slices.json`：在顶层 `planned` 里加 `candy_1`（照 `jeju_1`，`top_edge: "sky"`，加 `short_name`），`rooms2` 写计划中的房间 id。**不要**放进 `entries` 或开局池 `delivery_pool`（房间还没做，会生成失败）；
   - `recipients.json`、`cargo.json`、`monsters.json`：加新条目。
3. **写后续工作包**（照 `docs/packages/README.md` 末尾的模板：包头写全基线、分支、开工（`git worktree`）和交回命令；有「预计」「要读的（只读这些）」两档「检查」；交付不超过 40 行；验收写成"运行什么 → 看到什么"）。用下面预留的编号：
   - **ART-02a 美术①**：主题 `theme.candy`（新建 `workbench/js/core/terrain-candy.js`，照 `terrain-jeju.js`，只接管这张图的地形和背景）+ 装饰。规则材料（土、裂石、沙、水）的画法必须和 `terrain.js` 一样。
   - **ART-02b 美术②**：4 位收件人的角色和滚轮头像（8 项）。
   - **ART-02c 美术③**：怪物、提示动物、货物（含损坏状态）、零食，以及机关在这张图里的外观。超过 8 项就再拆成 ART-02d。
   - **DLV-08 规则支持**：v2 回合规则支持 `bounce`、`melt`（要达到的行为、测试房、验收），照 DLV-05。
   - **DLV-09a 普通房**（起点、过道、驿站、收件人之家）、**DLV-09b 机关房 + 进开局抽签**（照 DLV-04a / 04b；04b 那次要改两条写死"地图数"的测试预期，写进可改清单）。DLV-09b 依赖 DLV-08。
   - 每个美术包都写：新资产第 1 版、status `review`，不能自己确认；`workbench/index.html`、`tools/art.mjs` 只追加；新字体文件要同时进三处字体清单（process.md 第 10 节）。
   - 依赖写清楚：三个美术包互不依赖、可以同时做；DLV-08 不依赖美术；DLV-09a 依赖 ART-02a（要地形）；DLV-09b 依赖 DLV-08 和 DLV-09a。
4. **登记表**：`docs/packages/README.md` 里把已预留的这几行填好（内容、基线 → 分支、会碰的共享文件、状态「待派」或「等 X 合并」）。
5. 地区名、角色名写在设计目录里；**不改** `content/i18n/*.json`。
6. 巧克力河：如果照水的现有规则就够用（浮、沉），写明"沿用水的规则，只换外观"，不另写规则；不够用就写进待定问题。

验收和下面「可改的文件」清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 可改的文件
- 新建：`docs/design/delivery-candy.md`；`docs/packages/ART-02a.md`、`ART-02b.md`、`ART-02c.md`（需要时 `ART-02d.md`）、`DLV-08.md`、`DLV-09a.md`、`DLV-09b.md`
- `content/catalog/worlds.json`、`slices.json`（只在 `planned` 里加）、`recipients.json`、`cargo.json`、`monsters.json`：只动 `candy` 的条目
- `docs/design/worlds.md`：只改「糖果王国」那一行（状态和设计文档链接）
- `docs/packages/README.md`：只改上面预留的几行
- 生成文件（用工具生成后提交，不手改）：`content/export/*`、`workbench/data/*`
- 本文件的状态和「交付」

## 不能碰的文件
- 美术和冻结区（AGENTS.md 2a）：`art/**`、`workbench/js/core/**`、`content/i18n/**`
- 已有地图的设计和数据（石牢、地府、海女村），房间 `content/rooms/**`、开局池
- 代码：`tools/**`、`workbench/**`（生成的 `workbench/data/*` 除外）、`tests/**`、`game/**`
- `docs/status.md`

## 检查
边做边跑：`node tools/content.mjs check`
最后跑一次：
```bash
node tools/content.mjs build && node tools/content.mjs check   # 0 错误、0 警告
node tools/check-rooms2.mjs     # 和改前一样，全部通过（candy_1 不在开局池里）
node tools/art.mjs build        # 0 bumped，确认记录 8 条
```
不要做的：逐个算文件哈希、复制仓库做试验、为写交付补跑命令（process.md 第 10 节）。

## 交付（制作方填写，不超过 40 行）
- 设计文档 7 节各一句（机制怎么用、房间几间）
- 美术清单：三批各几项
- 拆出的包：编号、一句话内容、依赖
- 上面检查各一行结果
- 遗留问题 / 待定问题里需要用户定的（没有写"无"）
（分支名、提交号、`git diff --stat` 贴在给用户的回复里，不写进这个文件）
