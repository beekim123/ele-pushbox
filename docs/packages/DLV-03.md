# DLV-03 配送 v2 外观修正：地府顶边、梯顶、配送菜单（工作台）

状态：待做（用户 2026-10-17 决定；只改 HTML 工作台，不碰 `game/`）
基线：`claude/inspiring-ride-zfnn4s` → 分支：`dlv/DLV-03`（**不要**从 `main` 开：`main` 现在还是旧内容）

**开工**（照抄）：
```bash
git fetch origin
git checkout -b dlv/DLV-03 origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin dlv/DLV-03`
- 不能推送：`git bundle create DLV-03.bundle origin/claude/inspiring-ride-zfnn4s..dlv/DLV-03`，把 `DLV-03.bundle` 交给用户

只往 `dlv/DLV-03` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

会碰的共享文件：`workbench/index.html`、`tools/art.mjs`（只追加）、`workbench/js/app/nav.js`、`tests/workbench.e2e.cjs` 的菜单检查
允许换版本的美术：无（`art.mjs build` 必须 0 bumped）
设计依据：
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 第 8 节（顶边、梯顶）
- [art-direction.md](../design/art-direction.md) 第 6 节「顶边画成天空」
- [workbench.md](../design/workbench.md) 第 6.1 节（配送菜单）

## 目标
1. **地府顶边画成天空**：`slices.json` 里写了 `"top_edge": "sky"` 的地图（现在只有 `diyu_1`，设计负责人已经写好），房间顶上 1–2 格厚的石头不画，露出背景。哪些格算天空，严格按第 8.1 节。石牢和其他地图不变。
2. **v2 梯顶**：v2 房间的梯顶和关卡模式一样只画最下面 4 px（第 8.2 节）。现在 `ladder-tops.js` 只包了 v1 的 `PB.droom`，没有包 v2 的 `PB.droom2`；梯顶判断要用同一套代码，不要复制一份。
3. **配送菜单按地图列出**：按第 6.1 节，左侧菜单「配送」下依次是：
   - 开局池
   - 每张 v2 地图各一项，用地图自己的名字，从 `slices.json` 生成
   - 幽暗石牢（v1 切片）
   - 新增地图页 `#rooms2/map/<地图>`；旧网址都还能打开。

## 要读的文件
- AGENTS.md（尤其 0、2、2a 条）、`docs/packages/README.md` 的共同规则
- 上面三份设计文档的对应章节；[LAD-01](LAD-01.md) 的交付
- `workbench/js/core/delivery-scene2.js`（`PB.droom2`，地形和背景在 `draw` 里画）、`workbench/js/core/terrain-diyu.js`、`workbench/js/app/ladder-tops.js`
- `workbench/js/app/nav.js`、`main.js`、`views/rooms2.js`、`views/maps.js`、`index.html`
- `tests/workbench.e2e.cjs`（菜单顺序检查、2e、2f 节）、`tests/rooms2.test.mjs`

## 要产出或修改的文件
- `workbench/js/core/delivery-scene2.js`：天空格的判断与画法、调用梯顶判断。也可以把天空格的判断放进新文件 `workbench/js/core/rooms2-look.js`，在 `index.html` 和 `tools/art.mjs` 的 `loadCore` 里加载。
- `workbench/js/app/ladder-tops.js`：让 `PB.droom2` 也用上梯顶判断。
- `workbench/js/app/nav.js`、`main.js`、`views/rooms2.js`、`index.html`、`css/workbench.css`：配送菜单与地图页。
- 测试：
  - `tests/rooms2.test.mjs` 加天空格判断的单元测试，至少包括 `diyu_naihe`（第 3–9 列连续 3 格要照常画，其余顶上两行是天空）、一间 `dungeon2_*`（没有天空格）、两屏高的 `diyu_fengdu`（第 10–11 行不算）。
  - `tests/workbench.e2e.cjs`：菜单顺序检查改成新菜单；加地图页、旧网址、面包屑的检查。
- 生成文件按共同规则第 2 条重新生成（`node tools/content.mjs build`、`node tools/art.mjs build`）。
- 截图：放在 `docs/packages/DLV-03/`，`diyu_naihe`、`diyu_fengdu`、`diyu_lantern`、`dungeon2_well` 各一张改前、一张改后，外加新菜单一张。

## 不能碰的文件
- AGENTS.md 2a 的冻结区：
  - `art/source/**`、`art/approvals.json`、`art/history/**`、`art/export/approved/**`
  - `workbench/js/core/` 下已有的绘制文件（`terrain.js`、`scene.js`、`sprites.js`、`ui*.js` 等）。`terrain-diyu.js` 也不要改：它参与候选 `theme.diyu` 的内容哈希，改了会换版本。天空格由 `delivery-scene2.js` 决定画不画，地形图案本身不用动
  - `content/i18n/*.json`
- 房间数据 `content/rooms/**`、`content/catalog/**`、`workbench/js/core/rooms2.js`、`mapgen2.js`：这一包不改规则和房间。
- 设计文档：有疑问写进「交付 · 问题」。
- `game/**`

## 验收标准
- 命令（全部通过）：
  - `node tools/content.mjs check` → 0 错误
  - `node tools/check-rooms2.mjs` → 全部通过，结果与改前相同（这一包不改规则）
  - `node tools/art.mjs build` → **0 bumped**，确认记录仍是 6 条
  - `node tools/art.mjs verify` → ok
  - `node --test tests/*.test.mjs`、`node tests/workbench.e2e.cjs` → 全部通过
- 画面：
  - 地府房间顶上不再有一整条石头，露出夜空；连续 3 格以上的石柱照常画。
  - 梯子不再在平台上方多出一截。
  - 石牢顶上照旧。
- 菜单：左侧「配送」下能看到「开局池」「废弃的符文监狱（石牢重做）」「地府·酆都」「幽暗石牢（v1 切片）」；点地图只列这张地图的房间。
- 改动范围只在上面「要产出或修改的文件」里（`git diff --stat` 贴进交付）。

## 交付（制作方填写）
