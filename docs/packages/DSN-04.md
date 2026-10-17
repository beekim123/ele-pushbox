# DSN-04 第四张配送地图「极地雪村」：设计（只写设计和后续工作包）

状态：**已合并**（2026-10-17，bundle `ffb7e2f`）
基线：`claude/inspiring-ride-zfnn4s` → 分支：`dsn/DSN-04`（**不要**从 `main` 开：用户决定先不合进 main）
预计：3 小时；超过 4 小时还没做完就停下，把进度写进「交付」交回。
可以和 DSN-05（糖果王国） 同时做：两包都往设计目录里加条目，只动自己地图的条目，合并冲突由 Claude 处理。

**开工**（照抄；用自己的工作目录，不和别的窗口共用）：
```bash
git fetch origin
git worktree add ../ele-pushbox-DSN-04 -b dsn/DSN-04 origin/claude/inspiring-ride-zfnn4s
cd ../ele-pushbox-DSN-04
```
**交回**（二选一）：
- 能推送：`git push -u origin dsn/DSN-04`
- 不能推送：`git bundle create DSN-04.bundle origin/claude/inspiring-ride-zfnn4s..dsn/DSN-04`，把 `DSN-04.bundle` 交给用户

只往 `dsn/DSN-04` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

## 目标
写出配送模式新地图「极地雪村」（地区 id `polar`，地图 id `polar_1`）的**完整设计**，并把美术和房间拆成能直接派的小包。
**这一包只写文档和设计目录**：不画美术、不写代码、不做房间。（济州那次设计 + 美术放一个包，太大，做到后面出错，所以这次拆开。）

## 用户的要求
1. **明亮、开阔**：白天的雪原、冰湖、冰屋、木屋，远处有雪山，傍晚可以有极光。配色以白、浅蓝为主，和石牢、地府（黑暗）、海女村（蓝海暖阳）都不一样。
2. **不圈住**：照 [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 8.1、8.3 节：`top_edge: "sky"`，地形从下往上长，上面大部分是天空，多用 2×1 宽房间，边界画成自然物。
3. **专属机制**：以冰面滑行为主：推到冰上的箱子一直滑到撞上东西才停；可配合冷凝成冰、热喷化冰。worlds.md 写的"雪球越滚越大"（`snowball`）目前没有任何实现，要新规则，这次**不做**，写进待定问题。
   - 优先用关卡模式里已经有的机制（`ice_slide`、`freeze`、`melt`）。它们在 `workbench/js/core/mech/` 有关卡模式的实现，但**配送 v2 的回合规则（`rooms2.js`）还不支持**，所以要写一个规则支持包（照 [DLV-05](DLV-05.md) 给跷跷板 / 阵风做的那样）。
   - 不发明需要新物理的机制。worlds.md 表里写的"寒冷值"这类新系统**不做**。
4. 配送 v2 的规则全部照用：先教后用、每间房只教或只用一件事、怪物不进解谜区、必需机制、不靠摔、提示和解法一致。

## 要读的（只读这些）
- [delivery-jeju.md](../design/delivery-jeju.md)：上一张地图，**照它的 7 节结构写**
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 第 3–6 节、第 8 节
- [worlds.md](../design/worlds.md) 第 2 节、第 3 节地区表里「极地雪村」那一行
- [art-direction.md](../design/art-direction.md)：只看调色板和尺寸规定
- `content/catalog/worlds.json` 的 `jeju` 和 `polar`、`slices.json` 的 `jeju_1`：数据怎么写
- `workbench/js/core/mech/` 下 `ice_slide`、`freeze`、`melt` 的文件：只看开头的说明，知道规则是什么

## 要做的
1. **新文档 `docs/design/delivery-polar.md`**，照 `delivery-jeju.md` 的 7 节写：
   1. 主题与画风：配色（用调色板代码）、地形图案、背景、装饰；写清和石牢、地府、海女村怎么区分。
   2. 收件人 4 位、货物 3–4 种：稀有度、规则、喜欢什么、住哪间收件人之家，`cargo_only` 写清。worlds.md 的候选是雪人、极地渔夫；可以加灯塔看守、驯鹿牧人。货物要有怕冷或怕摔的（例如热汤罐、毛线手套）。
   3. 怪物 2 种：行为、怎么对付（推、压、困）、出现在哪。worlds.md 的候选是雪怪、企鹅（滑行撞人）；企鹅如果做怪物，就不能再做提示动物。
   4. 房间表 12–13 间：名字、角色、大小、关键想法 → 变化、needs / teaches / requires、怪物、出入口；`layout.sequence` 和地图方向。**分成"普通房"和"机关房"两组**（后面分两个包做）。
   5. 提示动物：一只地上走的（收零食）+ 一只会飞的（只带路），零食在这张图的包装。不能和怪物混淆。
   6. 美术清单：全部候选（编号、尺寸、动作）。**按下面第 3 步分成 3 批，每批不超过 8 项。**
   7. 待定问题：每个 2–3 个选项和好坏，写明这次先按哪个做。
2. **设计目录**（只动 `polar` 的条目，新条目加在各自数组末尾）：
   - `worlds.json` 的 `polar`：补齐 `theme`、`hint_fauna`、`ambient_exclude`、`status`，照 `jeju`；
   - `slices.json`：在顶层 `planned` 里加 `polar_1`（照 `jeju_1`，`top_edge: "sky"`，加 `short_name`），`rooms2` 写计划中的房间 id。**不要**放进 `entries` 或开局池 `delivery_pool`（房间还没做，会生成失败）；
   - `recipients.json`、`cargo.json`、`monsters.json`：加新条目。
3. **写后续工作包**（照 `docs/packages/README.md` 末尾的模板：包头写全基线、分支、开工（`git worktree`）和交回命令；有「预计」「要读的（只读这些）」两档「检查」；交付不超过 40 行；验收写成"运行什么 → 看到什么"）。用下面预留的编号：
   - **ART-01a 美术①**：主题 `theme.polar`（新建 `workbench/js/core/terrain-polar.js`，照 `terrain-jeju.js`，只接管这张图的地形和背景）+ 装饰。规则材料（土、裂石、沙、水）的画法必须和 `terrain.js` 一样。
   - **ART-01b 美术②**：4 位收件人的角色和滚轮头像（8 项）。
   - **ART-01c 美术③**：怪物、提示动物、货物（含损坏状态）、零食，以及机关在这张图里的外观。超过 8 项就再拆成 ART-01d。
   - **DLV-06 规则支持**：v2 回合规则支持 `ice_slide`、`freeze`、`melt`（要达到的行为、测试房、验收），照 DLV-05。
   - **DLV-07a 普通房**（起点、过道、驿站、收件人之家）、**DLV-07b 机关房 + 进开局抽签**（照 DLV-04a / 04b；04b 那次要改两条写死"地图数"的测试预期，写进可改清单）。DLV-07b 依赖 DLV-06。
   - 每个美术包都写：新资产第 1 版、status `review`，不能自己确认；`workbench/index.html`、`tools/art.mjs` 只追加；新字体文件要同时进三处字体清单（process.md 第 10 节）。
   - 依赖写清楚：三个美术包互不依赖、可以同时做；DLV-06 不依赖美术；DLV-07a 依赖 ART-01a（要地形）；DLV-07b 依赖 DLV-06 和 DLV-07a。
4. **登记表**：`docs/packages/README.md` 里把已预留的这几行填好（内容、基线 → 分支、会碰的共享文件、状态「待派」或「等 X 合并」）。
5. 地区名、角色名写在设计目录里；**不改** `content/i18n/*.json`。

验收和下面「可改的文件」清单冲突时，以清单为准，把做不到的写进交付，不要想办法绕过。

## 可改的文件
- 新建：`docs/design/delivery-polar.md`；`docs/packages/ART-01a.md`、`ART-01b.md`、`ART-01c.md`（需要时 `ART-01d.md`）、`DLV-06.md`、`DLV-07a.md`、`DLV-07b.md`
- `content/catalog/worlds.json`、`slices.json`（只在 `planned` 里加）、`recipients.json`、`cargo.json`、`monsters.json`：只动 `polar` 的条目
- `docs/design/worlds.md`：只改「极地雪村」那一行（状态和设计文档链接）
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
node tools/check-rooms2.mjs     # 和改前一样，全部通过（polar_1 不在开局池里）
node tools/art.mjs build        # 0 bumped，确认记录 8 条
```
不要做的：逐个算文件哈希、复制仓库做试验、为写交付补跑命令（process.md 第 10 节）。

## 交付（制作方填写，不超过 40 行）
### 设计文档 `docs/design/delivery-polar.md`
- 1 主题：冬天的白天，亮天空 + 压暗的雪松林剪影，盖雪的深蓝灰花岗岩；`terrain-polar.js` 只接管图案和背景，规则材料照旧；傍晚可选极光。
- 机制只用已验证的冰面滑行、冷凝、化冰（F07、F02、F03、F09）；雪球、寒冷值不做（待定第 3、4 条）。
- 2 收件人 4 位（雪人、极地渔夫、驯鹿牧人、独角鲸），货物 3 种（热汤罐怕冷、毛线手套怕湿、冰灯怕摔），`cargo_only` 写清。
- 3 怪物 2 种：企鹅（能推，推了也滑；压、困）、雪怪（推不动；压、困），只在两间喘口气的房里。
- 4 房间 13 间：普通 6（起点、喘口气 2、驿站、收件人之家 2）+ 机关 7（教 3、发展 2、转折 2）；序列同济州，`right`，16 × 2。
- 教冷凝、教化冰 `needs` 滑行，冰湖总是第一间教；转折房跟着第二间教的机制走；「必需滑行」统一用"人站压板开门、箱子自己滑过门"。
- 5 提示动物：小驯鹿（喂燕麦饼，图标另做 `item.snack_polar`）+ 雪鹀（只带路）。
- 6 美术 21 项分三批；7 待定问题 14 条，每条有选项和这次的做法。
### 美术清单
- ART-01a 7 项（主题 + 4 装饰 + 2 提示动物）、ART-01b 8 项（4 角色 + 4 头像）、ART-01c 6 项（2 怪物 + 3 货物 + 零食）。
- 冷热气口用已确认的 `mech.frost_vent` / `mech.heat_vent`，没有 ART-01d。
### 拆出的包
- ART-01a 主题、`terrain-polar.js`、装饰、提示动物；ART-01b 收件人角色和头像；ART-01c 怪物、货物、零食。三包都只等 DSN-04 合并，互不依赖。
- DLV-06 v2 规则支持冰面滑行、冷凝、化冰 + 5 间测试房；不依赖美术；和 DLV-08 改同一批文件，不同批派。
- DLV-07a 6 间普通房 + `worlds.json` 补主题和提示动物；等 ART-01a。
- DLV-07b 7 间机关房 + 进开局抽签（含两处写死地图列表的测试）；等 DLV-06、DLV-07a；和 DLV-09b 不同批。
### 检查（最后跑一次）
- `node tools/content.mjs build && node tools/content.mjs check`：0 错误、0 警告。
- `node tools/check-rooms2.mjs`：36 间全部通过；300 个种子 diyu_1 107、dungeon_2 100、jeju_1 93，`polar_1` 不在池里。
- `node tools/art.mjs build`：159 assets，0 bumped，8 条确认记录（只改了 `bundle.js` 的时间戳，没提交）。
### 和本包要求不一样的地方
- `worlds.json` 的 `theme`、`hint_fauna`、`ambient_exclude` 没填：资产还不存在，填了内容检查报 4 个错误。文字写在设计第 5 节，由 DLV-07a 填。
- 提示动物从美术③移到 ART-01a：主题的生态要列上雪鹀，放同一批三包才能互不依赖。
- worlds.md 那一行只加了状态和链接；表里的"雪球、寒冷值"没改（不在可改范围），以设计稿为准。
### 要用户定的
- 待定第 5 条企鹅（南北极混着）、第 10 条气口要不要雪村专属外观、第 11 条极光默认开不开、第 14 条名字；其余先按推荐做。
