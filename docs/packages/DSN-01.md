# DSN-01 第三张配送地图「济州海女村」：设计 + 美术候选

状态：待做
基线：`claude/inspiring-ride-zfnn4s`（BR-01 做完后改为 `main`）→ 分支：`dsn/DSN-01`
设计依据：
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md)：全文，尤其第 8 节
- [delivery-diyu.md](../design/delivery-diyu.md)、[delivery-dungeon.md](../design/delivery-dungeon.md)：已做完的两张地图，照它们的格式
- [worlds.md](../design/worlds.md) 第 2 节、3.3 节「济州海女村」、第 4 节
- [art-direction.md](../design/art-direction.md)、[art-pipeline.md](../design/art-pipeline.md)

会碰的共享文件：
- `content/catalog/worlds.json`、`slices.json`、`recipients.json`、`cargo.json`、`monsters.json`：只加或改 jeju 的条目
- `workbench/index.html` 脚本列表、`tools/art.mjs` 的 `loadCore`：只追加 `terrain-jeju`
- `docs/packages/README.md` 登记表：只改 DLV-04、DLV-05 两行

允许换版本的美术：无。已有资产一个都不换版本；只新增 jeju 的候选（第 1 版，status `review`）。
预留编号：
- `DLV-04`：济州房间数据
- `DLV-05`：v2 规则支持跷跷板 / 阵风，需要时才用

## 目标
做出配送模式第三张地图「济州海女村」（建议 id `jeju_1`）的**完整设计和全部美术候选**。做完后：
- 用户在工作台「确认」页能看到这张图的所有美术候选，在「场景」页能看到它的地形和背景；
- 房间数据另拆成 DLV-04，交给下一个制作方做。

用户的要求：
1. **明亮**：前两张（石牢、地府）都偏黑暗，这一张是白天的海边：蓝海、晴天、黑色火山石墙、橘子树、海女、码头。
2. **不圈住**：
   - 用 `top_edge: "sky"`；
   - 地形从下往上长（礁石、石墙、码头栈道、橘子园台地），上面大部分是天空；
   - 多用 2×1 的宽房间；
   - 左右和底边逻辑上仍要挡人，但画成海水、礁石、石墙这类自然边界。
3. **专属机制**用已经验证过的跷跷板（`seesaw`）和阵风（`gust`）为主，见关卡 G09、G10、F08、E06；注意阵风只测过一种配置、余量很小。可以配合已有的水、浮箱、推箱、梯子；不发明需要新物理的机制。
4. 配送 v2 的规则全部照用：先教后用、每间房只教或只用一件事、怪物不进解谜区、必需机制、不靠摔、提示和解法一致。

## 第一步：设计
1. 新文档 `docs/design/delivery-jeju.md`，按 `delivery-diyu.md` 的结构写：
   - **主题与画风**：明亮海边的画面、配色、地形图案、背景、装饰；写清和石牢、地府怎么区分。按 worlds.md 2.1 节写清取材出处和注意事项：石头爷爷只作地标，不能推倒；小鬼怪（도깨비）要可爱，不吓人。
   - **收件人**（4–5 位，必须有海女奶奶）和**货物**（3–4 种）：稀有度、规则、喜欢什么、住在哪间收件人之家；`cargo_only` 写清楚。
   - **怪物**（2–3 种，建议小鬼怪：拦路摔跤，推出两格算赢；海鸥：抢东西）：行为、怎么对付（能不能推、压、困）、出现在哪。
   - **房间表**（10–13 间）：
     - 每间写名字、角色、大小、关键想法 → 变化、needs / teaches / requires、怪物、出入口方向；
     - 写定 `layout.sequence` 和地图方向。
   - **提示动物**：一只地上走的主动物（收零食）+ 一只会飞的（只带路），以及零食在这张图的包装。不能和怪物或随机生态混淆。
   - **美术清单**：第二步要画的全部候选（编号、尺寸、动作列表）。
   - **待定问题**：每个给 2–3 个选项和好坏，并写明这次先按哪个做。
2. `docs/design/delivery-puzzle-rules.md` 第 8 节加 **8.3「野外地图怎么做房间」**：地形从下往上长、顶上留天空、边界画成自然物、多用宽房间。写成森林、云端等以后的野外地图都能照用的通用规则。
3. 设计目录：
   - `worlds.json` 的 `jeju`：补齐 `theme`、`hint_fauna`、`ambient_exclude`、`status`，字段照 `diyu` 的写法；
   - `slices.json`：加 `jeju_1`（照 `diyu_1` 的字段，`top_edge: "sky"`），`rooms2` 写计划中的房间 id；
   - `recipients.json`、`cargo.json`、`monsters.json`：加新条目；
   - **不要**把 `jeju_1` 加进开局池 `delivery_pool`：房间还没做，加了会生成失败。这一步留给 DLV-04。
4. 写工作包：
   - `docs/packages/DLV-04.md`（济州房间数据）：照 README 模板，写清每间房的要求、`check-rooms2` 全部通过，最后把 `jeju_1` 加进开局池；
   - 如果 v2 回合规则（`workbench/js/core/rooms2.js`、`tilemodel.js`）还不支持跷跷板或阵风，再写 `DLV-05.md`：要达到的行为和验收条件。不需要就不写；
   - README 登记表里把这两行改成「待派」。
5. 世界名、角色名等写在设计目录里，照 `diyu` 的写法；**不改** `content/i18n/*.json`。如果确实需要新的界面文字，放新表 `content/i18n-jeju/`，缺的字形用 `python3 tools/build-font.py --ext jeju` 生成。

## 第二步：美术候选（按第一步的美术清单）
1. **主题 `theme.jeju`**：照 `theme.diyu` 和 `workbench/js/core/terrain-diyu.js` 的做法，新建 `workbench/js/core/terrain-jeju.js`，只接管 jeju 自己的地形图案和背景。
   - 地形：黑色玄武岩（多孔、圆石垒墙）、沙滩、码头木板、橘子园土台；
   - 背景：白天的海和天空，远处汉拿山，有云，海面有闪光；
   - **规则材料**（土、裂石、沙、水）的画法必须和 `terrain.js` 一样，可读性优先（art-direction 第 8 节）；
   - 在 `workbench/index.html`（`terrain-diyu.js` 后面）和 `tools/art.mjs` 的 `loadCore`（`terrain-diyu` 后面）**追加**加载。
2. **其他候选**：在 `art/source/<类别>/` 新建源文件，格式见 art-pipeline 第 2 节，照 `deco.diyu_lantern`、`char.meng_po`、`avatar.meng_po`、`monster.jiangshi`、`fauna.diyu_dog`、`cargo.qingtuan` 的写法，全部 status `review`：
   - 装饰（石头爷爷、橘子树等）；
   - 提示动物两只；
   - 怪物（含动作）；
   - 收件人角色与滚轮头像；
   - 货物（含损坏状态）；
   - 跷跷板 / 阵风在这张图里的外观（如果和关卡模式的不同）。
3. **规格**：调色、尺寸、动作按 art-direction。明亮但不刺眼；角色 Q 版；和已确认的主角 `char.portitor` 放在一起不突兀。
4. **对照图**：放在 `docs/packages/DSN-01/`：
   - 全部候选一张总览；
   - 主题地形和背景一张；
   - 一张"模拟房间"：用一间设计中的房间草图，摆上地形、角色、怪物、提示动物，看整体效果。可以用工作台「场景」页截图，或者用临时脚本出图，脚本不提交。

## 可改的文件
- 新建：
  - `docs/design/delivery-jeju.md`
  - `docs/packages/DLV-04.md`、`docs/packages/DLV-05.md`（需要时）、`docs/packages/DSN-01/**`（对照图）
  - `art/source/**/` 下 jeju 的新源文件（只新建，不改已有的）
  - `workbench/js/core/terrain-jeju.js`
  - `content/i18n-jeju/**`、`workbench/js/core/font-jeju.js`（需要时）
- 修改：
  - `docs/design/delivery-puzzle-rules.md`（只加 8.3）、`docs/design/worlds.md`（只改济州那段和地区表那一行）、`docs/design/art-direction.md`（只加济州主题一条）
  - `content/catalog/` 下上面列出的 5 个文件（只动 jeju 的条目）
  - `workbench/index.html`、`tools/art.mjs`（只追加加载 `terrain-jeju`，需要时加 `font-jeju`）
  - `docs/packages/README.md`（只改 DLV-04、DLV-05 两行）、本文件的状态和「交付」
- 生成文件：用工具重新生成后提交，不手改。

## 不能碰的文件
- AGENTS.md 2a 冻结区里已有的一切：
  - 已有的 `art/source/**`、`art/approvals.json`、`art/history/**`、`art/export/approved/**`
  - 已有的 `workbench/js/core/` 绘制文件，**包括 `terrain-diyu.js`**
  - `content/i18n/*.json`
- 石牢、地府的设计和数据；房间数据 `content/rooms/**`（留给 DLV-04）
- `rooms2.js`、`mapgen2.js`、`tilemodel.js`、`delivery-scene2.js`
- `docs/status.md`
- `game/**`
- **不能自己批准美术**，也不能把"测试通过"当作确认。

## 验收标准
- [process.md](../process.md) 第 6 节全套检查通过，其中：
  - `node tools/content.mjs check` → 0 错误；
  - `node tools/art.mjs build` → **0 bumped**，只有新增的 jeju 候选，确认记录仍是 6 条；
  - `node tools/art.mjs verify` → ok。
- 工作台：
  - 「确认」页能看到全部 jeju 候选；
  - 「资产与动画」页每个候选的动作都能播放；
  - 「场景」页能选 `theme.jeju` 看到地形和背景。
- 设计文档五部分齐全；DLV-04 包写好并在 README 登记。
- 交付里写出给用户确认用的命令（版本号以 build 结果为准）：
  `node tools/art.mjs approve --items <id@1,...> --by 用户 --via chat --scope "济州海女村美术" --note "<用户原话>"`

## 交付（制作方填写）
