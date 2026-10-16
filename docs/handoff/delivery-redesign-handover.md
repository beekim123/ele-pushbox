# 交接：配送模式重做（分支 `claude/delivery-redesign`）

> **更新（2026-10-16）**：第 4–7 步已在分支 `claude/delivery-redesign-next` 完成（基于 `3f59913`）。工作台「配送 v2」页的 HTML 在提交 `676e89e`、`34dc229`；工作台界面改版后按 [UI-08](../packages/UI-08.md) 重新接入。下面是开工前的交接内容，保留作记录。
>
> **状态（2026-10-16）**：第 1–3 步已完成并提交（`986cce0`，全部检查通过）；第 4–7 步**还没开始**，没有写了一半的代码。用户额度用完，换账号继续。新会话照本文做；文末第 6 节「交接提示词」可以直接交给新会话。
>
> 用户会附上 `delivery-redesign-handover.zip`：`ele-pushbox-delivery-redesign.bundle`（本分支完整 git 历史）、`scratch/`（生成脚本，不进仓库）、`research_cache/`（调研原文）、本文副本 `HANDOVER.md`、`PROMPT.md`（第 6 节）。

## 0 拿到代码和工具

1. 仓库克隆到 `/data/ele-pushbox`（`https://github.com/beekim123/ele-pushbox.git`）。如果用户已把分支推到 GitHub：`git fetch origin claude/delivery-redesign && git switch claude/delivery-redesign`；否则从 bundle 取：
   ```
   git fetch /data/handover/ele-pushbox-delivery-redesign.bundle claude/delivery-redesign:claude/delivery-redesign
   git switch claude/delivery-redesign
   ```
   分支基于 `claude/inspiring-ride-zfnn4s`（`3037800`），没有设置上游。
2. 仓库级身份：`git config user.name bee`，`git config user.email 1948428752@qq.com`。推送：`git push -u origin claude/delivery-redesign`（新分支，不强推；需要用户的 GitHub 授权，没有授权就 `git bundle create <文件> claude/delivery-redesign` 交给用户）。
3. `scratch/` 复制到 `/data/scratch/`，`research_cache/` 复制到 `/data/research_cache/`。脚本里写死了 `/data/ele-pushbox`、`/data/scratch` 路径。
4. 起点检查（都应通过）：`node tools/content.mjs check`（0 错误 0 警告）、`node tools/check-rooms2.mjs`、`node tools/art.mjs verify`、`node --test tests/*.test.mjs`（38 个通过）。

## 1 用户的边界（必须遵守）

- 不强推；不 `reset` / `clean` / `stash`；不改远程配置；避免 `rm -rf`。
- 不动 `main`、GPT 的关卡线 `codex/portitor-stage1`、UI 线 `ui/redo-html`；不改已确认的美术（`art/approvals.json`、manifest 里 `approved` 不为空的条目）；**不做 Godot 实现**。
- 这个分支**只写设计文档和 HTML 工作台**（以及支撑它们的检查工具和数据）；做完后由 Claude 审核。
- 冻结的核心绘制文件不改：`workbench/js/core/` 下 `raster.js`、`sprites.js`、`font-data.js`、`terrain.js`、`ambient.js`、`env.js`、`matter.js`、`scene.js`、`ui.js`、`i18n.js`、`tilemodel.js`（`docs/handoff/gpt-refactor-prompt.md` 0.3）。新画法放新文件（例：`terrain-diyu.js` 包装 `PB.terrain.drawBackground`）。
- 石牢画风不重做。新美术都是**候选**（status `review`），用户确认前不算定稿。
- 提交信息用英文（和仓库一致）；给用户的汇报用中文、简短。

## 2 用户已确认的设计决定（2026-10-16）

1. **浮空地块**：悬空 2–4 格、永远不掉；从侧面走进它的一端，整块推一格，上面的人、箱子、沙一起走；前方挡住就推不动。站在上面对着挖不动的墙 / 石柱 / 门用铲子 = **撑篙**，浮块带人往反方向挪一格。石牢是符文浮石，地府是会发光的灯笼浮台。
2. **房间可变大小**：1×1 到 2×2 屏（一屏 20×10 格，16 px 一格），加跟随镜头；**Tab 看全图**；画面外的怪物在屏幕边缘提示。
3. **第二张地图 = 地府·酆都**，中国风（不用冥河 `styx`）。
4. **开局随机抽池子**：先抽地图 → 再抽收件人（只在这张图的收件人里）→ 再抽货物（按地图过滤，`cargo_only` 限定某些货物只给某些收件人）；有重转次数。
5. **提示动物只做配送模式**，三级：① 它待的位置就是线索；② 走近时它看向 / 走向下一步要用的东西；③ 喂一块零食换一句明确提示。同样的局面总给同样的提示，不挡路、不受伤。石牢 = 牢猫（主）+ 蝙蝠；地府 = 小白狗（主）+ 彼岸蝶；其他 5 区各一行（已写进目录）。
6. 石牢主题叫「废弃的符文监狱」（符文浮石，猫 + 蝙蝠提示）。
7. 查 SDK 有没有可用机制（如岩浆）；**暂不做 SDK 新机制**。
8. 美术由 Claude 画候选，用户确认。

## 3 已完成（提交 `986cce0`）

### 3.1 规则与工具

| 文件 | 内容 |
| --- | --- |
| `workbench/js/core/rooms2.js` | `PB.rooms2`：房间格式 `pushbox.room/2`（`validate`、`variant` 镜像与封口、出入口 `<edge>.<段>.<slot>`，slot = `low` / `high`（左右）或 `mid`（上下）），浮块与撑篙（`act`、`floatAt`、`riders`），BFS 求解 `solve(v, from, to, {limit, frozen})`、回放 `replay`、`hurts`（落 ≥ 3 格摔伤，沙上不算），提示 `holds` / `nextHint` / `hintTrace`，`monsterProblems`（巡逻范围不进解谜区），镜头 `CAM`（视野 320×160，死区 ±24，前瞻 32，12 刻后生效，缓动，纵向跟随脚下平台）/ `cameraStart` / `cameraStep` / `clampCam` |
| `workbench/js/core/mapgen2.js` | `PB.mapgen2`：三个滚轮 `reels`（地图 → 收件人 → 货物，稀有度权重，`picks` = 重转后玩家选的结果，抽签次数不变）、`layout`（按地图的 `layout.sequence` 角色顺序深度优先摆房间，`FORBID_OUT` 禁止往回走，只用检查过的 `routes`）、`generate(seed, pool, maps, cat, templatesOf, picks)`、`tileRect`、`joints`。同种子 = 同一局 |
| `workbench/js/core/terrain-diyu.js` | 包装 `PB.terrain.drawTerrain` / `drawBackground`，只接管岩石图案 `wild` 和背景 `diyu`：荒郊野岭（wild 地形：深色泥土、枯草、根须；背景：夜空、残月、三层荒山、枯树、坟包和木牌、招魂幡和乌鸦、鬼火、两层夜雾）。第一版画的是城墙、城楼，2026-10-16 按用户反馈重做（提交 `988c9ba`）；已加入 `index.html` 和 `tools/art.mjs` 的 `loadCore` |
| `tools/check-rooms2.mjs` | 检查全部 v2 房间（每个摆法、每条 route：最短解、作者解、`requires` 必需机制、提示顺序、怪物不进解谜区）和开局池（默认 300 个种子）；`--write` 写 `content/rooms2-check.generated.json`；`--seeds N`、`--only <房间>`；导出 `loadRooms2`、`poolInput` |
| `tools/content.mjs` | 读 v2 房间和检查结果（缺失 / 过期报错）；`workbench/data/content.js` 多了 `rooms2`（房间 + `check`）和 `pools2`；`content-manifest.json` 多了 `rooms2` |
| `tools/check-rooms.mjs` | 跳过 format 2 的切片和开局池 |

### 3.2 房间（23 间）

格式字段：`format, world, id, type, role, size, name, idea, needs, teaches, requires, mechanisms, exits, routes ("a>b"), puzzle_area, links, devices, legend（数字 → {monster, zone, dir} 或 {feature}）, hints [{text, target, show{action, dir, at}, done}], hint_route, solutions {route: 动作}, caps, only {recipients, cargo}, weight, mirror, map`。地图字符：lab 地块 `#%es.HBI_|~=`、浮块 `F` / `G`、金币 `$`、数字 = legend。提示 `done` 谓词：`covers`（浮块盖住某格）、`crate`（+`kind`）、`player` 矩形、`empty`、`sand`、`door`、`lever`、`device`（+`value`）、`bag_sand`、`all` / `any` / `not`。

- 石牢（切片 `dungeon_2`，`content/rooms/dungeon/dungeon2_*.json`）：`gate`、`bridge`（teach，有作者解）、`pole`（teach，有作者解）、`corridor`（breather 2×1）、`ferry`（develop 2×1）、`well`（develop 1×2）、`yard`（develop 2×2）、`station`、`sandpour`（twist）、`home`。
- 地府（切片 `diyu_1`，`content/rooms/diyu/`）：`diyu_gate`、`lantern`（teach，有作者解）、`naihe`（teach）、`ghostfire`（breather）、`huangquan`（breather 2×1）、`fengdu`（develop 2×2）、`wangchuan`（develop 2×1）、`wangxiang`（develop 1×2）、`teahouse`（station）、`paper_bridge`（twist）、`sand_bridge`（twist）、`home_hall`、`home_yard`（home，`only` 限收件人）。
- 这些房间是用 `/data/scratch/rooms/*.mjs` 生成的（`lib.mjs`、`grid.mjs` 辅助，`dungeon*.mjs`、`diyu.mjs`，`printmaps.mjs` 打印地图）。重跑前先和仓库里的 JSON `git diff` 对比，别覆盖手改。

### 3.3 设计目录（`content/catalog/`）

机制 `float_block`、`pole`、`hint_animal`（experimental，owner game）；道具 `snack`；货物 `qingtuan` 青团、`paper_house` 纸扎房；收件人 `meng_po` 孟婆、`judge` 判官、`wuchang` 黑白无常、`yama` 阎罗王、`ancestor` 祖先；怪物 `imp` 小鬼、`wandering_soul` 游魂、`jiangshi` 僵尸；`worlds.hint_fauna`（dungeon、ruins、cave、forest、sky、cosmos、diyu）；`dungeon.ambient_exclude = [fauna.dungeon_rat, fauna.dungeon_bat]`；`diyu.theme = theme.diyu`、`ambient_exclude = [fauna.diyu_butterfly]`（提示动物不当随机生态）；切片 `dungeon_2`（12×3 屏，down）、`diyu_1`（13×3 屏，right，`cargo_only: {paper_house: [ancestor, wuchang]}`）、开局池 `delivery_pool`（两张图各权重 1，稀有度 common 4 / rare 2 / legendary 1，`rerolls: 1`）。这些由 `/data/scratch/catalog.mjs` 写入（可重跑，`--art` 加美术引用），之后 `node tools/content.mjs build`。

### 3.4 美术候选（24 项，status `review`，notes「配送重做的美术候选，等用户确认」）

- 石牢：`mech.rune_float`（left / mid / right 及 `*_move`）、`fauna.dungeon_cat`（sit / walk / meow）、`item.snack`（default / dungeon 小鱼饼干 / diyu 桂花糕）。
- 地府环境：`deco.diyu_lantern`（引魂灯：插在地上的竹竿纸灯；第一版是城墙上的红灯笼）、`deco.diyu_lily`（彼岸花）、`fauna.diyu_dog`（小白狗 sit / wag / walk / bark；原计划小黑狗在暗背景上看不见，所以改白）、`fauna.diyu_butterfly`（fly / rest）、`mech.lantern_float`、`theme.diyu`（procedural；荒郊野岭：wild 岩石图案 + 荒野夜色背景，引魂灯的光、萤火虫 / 余烬；规则材料和其他主题相同；第一版的城墙城楼已重做）。
- 地府角色：`monster.imp`（walk / chase / flee / stunned / trapped）、`monster.wandering_soul`（float / fade）、`monster.jiangshi`（idle / hop / trapped / ko）、`char.meng_po` / `judge` / `wuchang`（24×16，左白右黑）/ `yama` / `ancestor`（idle / win）、`avatar.<同上>`（24×24）、`cargo.qingtuan`（default / stale）、`cargo.paper_house`（default / damaged）。
- 改图：改 `/data/scratch/art/gen_dungeon.mjs`、`gen_diyu_env.mjs`、`gen_diyu_chars.mjs` → `node gen_*.mjs`（新资产总写成 version 1、无 hash；`DRY=1` 只预览）→ 回仓库 `node tools/art.mjs build && node tools/art.mjs verify`。预览：`node pv_pick.mjs out.png 6 <id> ...`、`pv_theme.mjs`（环境变量 VARIANTS / SCALE / TICK / OUT）。

### 3.5 检查结果

内容检查 0 错误 0 警告；`art.mjs build` 133 项、现有参考图未变、`verify ok`；`check-rooms2`：23 间全部通过；开局池 300 个种子全部生成成功（地图 151 / 149，每局 7–10 间、8–15 屏）；测试 38 / 38。

## 4 剩余工作（按顺序）

### 4.1 工作台「配送 v2」页（第 4 步）

新文件 `workbench/js/core/delivery-scene2.js`（`PB.droom2`）和 `workbench/js/app/views/rooms2.js`（`root.PBRooms2 = {show, hide}`），结构照抄 `views/maps.js`（`PBStage.create(host, {width, height, animated, autoplay, draw, disclaimer, extras})`、`PBStage.el`、`store.catalog()`、`store.content()`、`PBContentUI.mark / mechChip`、现有 CSS 类）。旧的「地图预览」页保持不动。

接线：`index.html` 导航加 `<a href="#rooms2" data-view="rooms2">配送 v2</a>`（放在「地图预览」后）和 `<section class="view" id="view-rooms2" hidden>`（`aside.side#rooms2-side`、`div.work#rooms2-work`、`aside.info#rooms2-info`）；**现在 `index.html` 还没加载 `rooms2.js`、`mapgen2.js`**：在 `mapgen.js` 后加这两个，`delivery-scene.js` 后加 `delivery-scene2.js`，`views/maps.js` 后加 `views/rooms2.js`；`main.js` 的 `VIEWS` 加 `rooms2: root.PBRooms2`。

数据：`store.content().rooms2`（检查报告里**没有存动作**：最短解在浏览器里现算 `PB.rooms2.solve(v, from, to, {limit: 250000})`，最慢约 80 ms；作者解 `R.expand(room.solutions[route])`，翻转时再 `R.mirrorActions`）；`store.content().pools2`（开局池统计）；`store.catalog("slices")` 里 `format: 2` 的地图和 `delivery_pool`。生成一局的参数照 `tools/check-rooms2.mjs` 第 98–104 行（`maps` = format 2 切片的 Map，`cat = {recipients: Map, cargo: Map}`，`templatesOf(sid)` = 切片 `rooms2` 对应的房间）。

功能：
1. **房间页** `#rooms2/<房间>`：整间房的画面（舞台尺寸 = W×16 × H×16，最大 640×320）、翻转、选 route、「作者解 / 最短解」逐步播放（◀ ▶）、路线点、解谜区和怪物巡逻范围、提示步骤列表（当前步 = `R.nextHint`）和提示动物位置、检查结果（errors / warnings / shortest / author / explored）。
2. **镜头**：320×180 = 上方 20 px HUD + 160 px 视野，从整间房的画面里裁出，`R.cameraStart / cameraStep` 跟着回放或试玩中的人；**Tab 切全图**；视野外的怪物在边缘画箭头。
3. **回合制试玩**：方向键走 / 爬，挖左 / 挖右 / 挖下、倒沙左 / 右，撤销，重来；用 `R.start` + `R.act(M, s, a)`，`R.hurts` 为真就拒绝并提示摔伤；到出口提示通过。提示动物三级：远处 = 位置提示；人走到 3 格内 = 它移到目标上 / 看向人，并在 `show.at` 画 `show.dir` 箭头；按 H 喂零食 = 主动物头顶出 `text` 气泡（`PB.dialogue.bubble`）。
4. **开局池页** `#rooms2/pool[/<种子>]`：三个滚轮依次停（地图 → 收件人 `avatar.<id>` → 货物 `cargo.<id>`），重转按钮（次数 = `pool.rerolls`，重转后用 `picks` 重新生成），然后画种子地图总览（cols×rows 屏的格子，每间房画成缩略地块图，含浮块；顺序编号、角色颜色；`mapgen2.joints` 检查），点房间跳到那间的房间页（带翻转和 route）；旁边显示 `pools2` 统计。

画法要点（`delivery-scene2.js`）：
- 不能直接用 `PB.scene.renderLevel`（它按固定 320×180 居中）。在房间坐标里（ox = oy = 0）自己串一遍 `scene.js` 第 37–100 行的顺序，复用 `PB.terrain.drawBackground(r, theme, 0, 0, w, h, tick)`、`drawTerrain`、`PB.ambient.draw`（先 dry 跑一遍收集灯光）、`PB.env.draw`（back / light / front）、`PB.matter.drawMaterials / drawDevices / drawFx`、梯子 / 压板 / 门 / 箱子的画法。主题用 `PB.droom.themeId(world)`（会去掉 `ambient_exclude` 里的随机生态）。
- 浮块在格子模型里是岩石（`start()` 把 F / G 换成 `#`），位置在 `s.floats [{n, x, y, w}]`：画地形时把浮块盖住的格当空，再逐格画 `mech.rune_float`（石牢）/ `mech.lantern_float`（地府）的 `left / mid / right`，刚移动的 2–3 刻用 `*_move`；锚点先查 `art/source/mechanism/`。
- 角色：怪物 `monster.<id>`，收件人 `char.<id>`（`old_miner` → `char.miner`），驿站掌柜先查 `diyu_teahouse.json` 的 legend，没有专门美术就用 `char.turtle_keeper` 或 `PB.droom.placeholder`。
- 提示动物分工（建议，写进规则 §5）：`show.action` 是 `walk` / `climb`（去哪儿）→ 飞的（蝙蝠倒挂在目标上方的天花板 / 彼岸蝶停在目标上方）；其余（`push`、`lever`、`dig`、`pour`、`pole`）→ 主动物（猫 / 狗坐在目标旁边最近的能站的空格）。只有主动物收零食；喂飞的显示目录里的 `fed` 文案。
- 检查：用 Playwright 打开 `file:///data/ele-pushbox/workbench/index.html#rooms2/...`，确认没有控制台错误，逐间房截图看一遍。

### 4.2 文档（第 5 步）

新文档：
- `docs/research/2026-10-16-delivery-redesign.md`（写明来源）：游戏参考 Animal Well、Baba Is You、Carto、Celeste、Monument Valley、Professor Layton、Spelunky、Toki Tori 2（提示、镜头、浮台的做法）；地府资料（维基百科中英文：酆都 / 丰都鬼城、鬼门关、黄泉、奈何桥、孟婆、望乡台、判官、黑白无常、阎罗王、牛头马面、钟馗、城隍、纸扎、冥币、河灯、孔明灯、石蒜、中元节、殭屍，原文在 `/data/research_cache/`，`fetch.py` 里有抓取地址）；岩浆评估：目录已有 `lava`（来自恐龙区），SDK 的液体 + 温度 + 反应可以拼出来，但属于 SDK 新机制，按用户决定暂不做。
- `docs/design/delivery-puzzle-rules.md`：§1 解谜原则（每间房只教或只用一件事、怪物不进解谜区、必需机制检查、不靠摔）；§2 `room/2` 格式（3.2 的字段）；§3 浮块与撑篙的精确规则（按 `rooms2.js` 的 `act` / `moveFloat`）；§4 镜头（`CAM` 数值、Tab 全图、边缘提示）；§5 提示动物（三级、`nextHint` 确定性、`done` 谓词、主 / 飞分工、零食）；§6 开局池与布局（抽签顺序、权重、重转、`cargo_only`、`layout.sequence` 与 `chance`、`FORBID_OUT`、同种子同局）；§7 检查工具。
- `docs/design/delivery-dungeon.md`（废弃的符文监狱：主题、10 间房的想法、机制、怪物、猫 + 蝙蝠、配送模式关掉随机老鼠和蝙蝠、美术）。
- `docs/design/delivery-diyu.md`（酆都：收件人、货物、怪物、13 间房、`terrain-diyu.js`、美术候选清单、小白狗改色理由）。

更新：`mode-delivery.md`、`delivery-maps.md`（指向 v2）、`delivery-slice.md`、`worlds.md`（其他 5 区的提示动物各一行）、`art-direction.md` 第 6 节（提示动物规则；配送模式关掉石牢随机蝙蝠）、`docs/README.md`。

工作包（`docs/packages/`，模板见其中 README，并更新 README 列表）：v2 实时规则（浮块推 / 撑篙在 60 刻模型里的时序，游魂飘、僵尸跳的移动）、v2 的 Godot 实现（房间、镜头、提示动物、开局池）、`UI-07`（三滚轮、提示气泡、观察模式、多屏小地图、零食）。

### 4.3 测试（第 6 步）

`tests/rooms2.test.mjs`：浮块带人带箱推一格、前方挡住推不动、撑篙往反方向、摔 3 格算伤、`mapgen2` 同种子同结果、`checkRooms2` 失败数为 0。加载方式照现有 `tests/*.test.mjs`。

### 4.4 收尾（第 7 步）

```
node tools/content.mjs build && node tools/content.mjs check
node tools/check-levels.mjs && node tools/check-rooms.mjs && node tools/check-rooms2.mjs --write
node tools/art.mjs build && node tools/art.mjs verify
node --test tests/*.test.mjs
```

更新 `docs/status.md`，提交，推送 `claude/delivery-redesign`。向用户中文简报：待确认美术 24 项（3.4）、岩浆评估、待加深的房间（第 5 节）、还没做的事。

## 5 已知问题 / 待加深

- `diyu_paper_bridge`、`diyu_wangchuan` 基本一路按右就能过，要加深。
- 石牢 teach / twist 模板太少，开局顺序总是 `bridge → pole`、twist 总是 `sandpour`；要多做几间。
- 黑白无常分两份规则（白收 / 黑收）、纸扎房被风吹坏：暂缓。
- 怪物只做了静态检查（巡逻范围不进解谜区），v2 房间还没有实时演示。

## 6 交接提示词

<!-- PROMPT-START -->
你接手《渡界人 / PORTITOR》仓库（https://github.com/beekim123/ele-pushbox.git）里「配送模式重做」这条线（分支 `claude/delivery-redesign`），继续上一位 Claude 没做完的部分：工作台「配送 v2」页、设计文档和工作包、测试、收尾提交。

用户会附上 `delivery-redesign-handover.zip`：`ele-pushbox-delivery-redesign.bundle`（分支完整历史）、`scratch/`（生成脚本）、`research_cache/`（调研原文）、`HANDOVER.md`（交接文档）。

开始前：
1. 解压到 `/data/handover/`。把仓库克隆到 `/data/ele-pushbox`；如果用户已经推送了分支，就 `git fetch origin claude/delivery-redesign`，否则 `git fetch /data/handover/ele-pushbox-delivery-redesign.bundle claude/delivery-redesign:claude/delivery-redesign`；然后 `git switch claude/delivery-redesign`。设置仓库级身份 `git config user.name bee`、`git config user.email 1948428752@qq.com`。
2. 把 `scratch/` 复制到 `/data/scratch/`，`research_cache/` 复制到 `/data/research_cache/`（脚本里写死了这些路径）。
3. 通读 `docs/handoff/delivery-redesign-handover.md`（就是 HANDOVER.md），再看 `AGENTS.md`、`docs/status.md`、`docs/design/mode-delivery.md`、`delivery-maps.md`、`delivery-realtime.md`、`workbench/js/core/rooms2.js`、`mapgen2.js`、`workbench/js/app/views/maps.js`。
4. 跑一遍起点检查（应全部通过）：`node tools/content.mjs check`、`node tools/check-rooms2.mjs`、`node tools/art.mjs verify`、`node --test tests/*.test.mjs`。

然后按交接文档第 4 节的顺序做完：4.1 工作台「配送 v2」页 → 4.2 文档和工作包 → 4.3 测试 → 4.4 全部检查、更新 `docs/status.md`、提交并推送（没有 GitHub 授权就打 bundle 给用户），最后用中文简短汇报。

必须遵守交接文档第 1 节：不强推；不 reset / clean / stash；不改远程配置；避免 rm -rf；不动 main、`codex/portitor-stage1`、`ui/redo-html`；不改已确认的美术和冻结的核心绘制文件；不做 Godot 实现；这个分支只写设计文档和 HTML 工作台。新美术都只是候选，等用户确认。每完成一大步先本地提交一次（英文提交信息）。用户额度有限：不要打印大文件，多用脚本统计和 grep。
<!-- PROMPT-END -->
