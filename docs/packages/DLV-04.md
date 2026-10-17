# DLV-04 济州海女村的 13 间房（配送 v2 房间数据）

状态：**已拆分**（2026-10-17，按 process.md 2.1）：[DLV-04a](DLV-04a.md)（7 间普通房，先做）→ [DLV-04b](DLV-04b.md)（6 间机关房、济州进开局抽签）。本文件的「每间房的要求」表是两包共用的参考，不再单独派。
基线：`claude/inspiring-ride-zfnn4s`（DSN-01、DLV-05 都合并以后）→ 分支：`dlv/DLV-04`（**不要**从 `main` 开；派之前 Claude 确认基线，换了就照新基线改下面两段命令）

**开工**（照抄）：
```bash
git fetch origin
git checkout -b dlv/DLV-04 origin/claude/inspiring-ride-zfnn4s
```
**交回**（二选一）：
- 能推送：`git push -u origin dlv/DLV-04`
- 不能推送：`git bundle create DLV-04.bundle origin/claude/inspiring-ride-zfnn4s..dlv/DLV-04`，把 `DLV-04.bundle` 交给用户

只往 `dlv/DLV-04` 提交；不往 `claude/inspiring-ride-zfnn4s`、`main` 或别的分支推送，也不合并别的分支。

设计依据：
- [delivery-jeju.md](../design/delivery-jeju.md)：全文，尤其第 4 节房间表、第 5 节提示动物
- [delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md)：全文，尤其第 1 节原则、第 2 节房间格式、第 5 节提示动物、第 6 节开局池、第 8 节顶边和 8.3 野外地图
- 已做完的两张：`content/rooms/diyu/`、`content/rooms/dungeon/` 和 [delivery-diyu.md](../design/delivery-diyu.md)
- 装置照验证关写：G09、G10（`content/levels/lab/react/`）、F08（`thermal/`）、E06（`experimental/`）

会碰的共享文件：`content/catalog/slices.json`（只动 `jeju_1` 和 `delivery_pool`）、`content/catalog/worlds.json`（只给 `jeju_dragonfly` 加 `fed`）、`content/i18n-rooms2/*.json`（只加 jeju 的键）、生成文件
允许换版本的美术：无（`art.mjs build` 必须 0 bumped）

## 目标
`content/rooms/jeju/` 的 13 间房全部通过 `check-rooms2`；`jeju_1` 进开局池，300 个种子三张地图都能生成；工作台配送 v2 能玩一局济州。

## 要做
1. 照第 4 节的表做 13 间房（下表是硬要求，房名、想法见设计文档）。文件 `content/rooms/jeju/<id>.json`，字段和写法照 `content/rooms/diyu/`，格式见规则第 2 节。
2. 每间房按第 8.3 节自查：每屏上面一半以上是天空，第 1 行能空就空；垂下来的山体至少 3 格厚；边框会画成两边石墙、底下礁石（地形图案 `jeju` 自动画，不用写）；码头栈道就是"下半屏、悬空、一格厚的石条"，要栈道就这样摆。
3. 机制房的装置照验证关：
   - 跷跷板 `{"type": "seesaw", "ends": [[x1, y], [x2, y]], "height": 2, "threshold": 1, "landings": [...]}`：`landings` 是端点上那格的 `x ± 1`、`y − height`，照 G09 / G10。
   - 阵风只用验证过的一种配置：`{"type": "gust", "area": [x, y, w, 1], "direction": "R", "period": 1, "phase": 0, "light_kinds": ["wood"]}`（F08；翻转后 `L` 由工具处理）。F08 的余量很小，作者解要多试几种走法确认没有捷径。
4. 提示照规则第 5 节写：主提示动物是济州小马（`fauna.jeju_pony`，收零食），会飞的是红蜻蜓（`fauna.jeju_dragonfly`，只带路）。`worlds.json` 的 `hint_fauna` 已经写好，只差红蜻蜓的喂食台词：`tests/rooms2.test.mjs`（第 199 行）要求会飞的提示动物的 `fed` 和文字表 `content/i18n-rooms2` 的 `dlg.fauna.<id>.fed` 一字不差，DSN-01 不能改文字表，所以没写。做第 5 条时一起加：`worlds.json` 的 `jeju_dragonfly` 加 `"fed": "只帮小马带路：喂零食要找小马"`，两张文字表加 `dlg.fauna.jeju_dragonfly.fed`（英文照 `dlg.fauna.diyu_butterfly.fed` 的句式，例如 "I only show the pony's way: feed the pony."）。
5. 房名、提示文字放进 `content/i18n-rooms2/zh-Hans.json` 和 `en.json`（键 `room2.<id>.name`、`room2.<id>.hint.<n>`，照 diyu），然后 `python3 tools/build-font.py --ext rooms2` 补字形。
6. 全部通过以后：
   - 把 `slices.json` 里的 `jeju_1` 从顶层 `planned` 移进 `entries`（放在 `diyu_1` 后面），删掉它的 `todo` 字段；`planned` 空了就整个删掉；
   - `delivery_pool.pool.maps` 加 `{"slice": "jeju_1", "weight": 1}`；
   - 看 300 个种子的统计（每局房间数、屏数），需要时调 `jeju_1.layout` 的 `cols` / `rows`（现在 16 × 2 是建议值）；
   - `node tools/check-rooms2.mjs --write` 重新生成报告；
   - 规则第 6 节的地图表加 `jeju_1` 一行，更新"300 个种子的统计"；`delivery-jeju.md` 开头的状态改成"13 间房全部通过 `check-rooms2`"，第 4 节写上和设计不同的地方。

**派的时候 DLV-05 还没合并**：只做下表"依赖 DLV-05"为"否"的 7 间，`jeju_1` 留在 `planned`、不进池；交付里写明，剩下的 6 间等 DLV-05 合并后另派。

## 每间房的要求

出入口写法见规则第 2 节（2×1 房间左右边只有屏段 0；1×2 房间 `left.1` 是下屏）。普通房的左低、左高都要有到出口的路线（前一间可能从高口出来）。

| 房间 | `type` / `role` | 大小 | 至少要有的出入口 | `teaches` / `requires` / `needs` | 装置 | 怪物 / 其他 | 依赖 DLV-05 |
|---|---|---|---|---|---|---|---|
| `jeju_gate` | gate / gate | 1×1 | `right.0.low`、`right.0.high` | — | — | 渡门 | 否 |
| `jeju_neolttwigi` | room / teach | 2×1 | 左低、左高 → 右低、右高 | 教 `seesaw`；必需 `seesaw`、`push` | 跷跷板 + 压板门（G09） | — | 是 |
| `jeju_baramgil` | room / teach | 1×1 | 左低、左高 → 右低、右高 | 教 `gust`；必需 `gust` | 阵风（F08 配置） | — | 是 |
| `jeju_olle` | room / breather | 2×1 | 左低、左高、右低、右高 | — | — | 海鸥、小鬼怪；路边要有头顶有遮挡的格子（躲海鸥） | 否 |
| `jeju_canola` | room / breather | 2×1 | 左低、左高、右低、右高 | — | — | 小鬼怪 | 否 |
| `jeju_pier` | room / develop | 2×1 | 左低、左高 → 右高 | 需要 `seesaw`；必需 `seesaw`、`push` | 跷跷板（一端在水底）、水、木箱 + 铁箱 | 海鸥只在解谜区外 | 是 |
| `jeju_terrace` | room / develop | 1×2 | 下屏左低、下屏左高 → 上屏右高、上屏右低 | 需要 `seesaw`；必需 `seesaw`、`dig`、`pour` | 跷跷板（G10）、土 | — | 是 |
| `jeju_doldam` | room / develop | 2×1 | 左低、左高 → 右低、右高 | 需要 `gust`；必需 `gust`、`push` | 阵风（F08）、压板门、木箱 + 铁箱 | — | 是 |
| `jeju_haenyeo_house` | station / station | 1×1 | 左低、左高、右低、右高 | — | — | 龟掌柜 | 否 |
| `jeju_dodaebul` | room / twist | 2×1 | 左低、左高 → 右高 | 需要 `seesaw`、`gust`；必需 `seesaw`、`gust` | 阵风 + 跷跷板（E06） | — | 是 |
| `jeju_home_shore` | home / home | 1×1 | 左低、左高 | — | — | 收件人；`only.recipients` 海女奶奶、灯塔大叔 | 否 |
| `jeju_home_orchard` | home / home | 1×1 | 左低、左高 | — | — | 收件人；`only.recipients` 橘园阿姨 | 否 |
| `jeju_home_cave` | home / home | 1×1 | 左低、左高 | — | — | 收件人；`only.recipients` 鬼怪大王；沙圈用规则的沙 | 否 |

## 要读的文件
- AGENTS.md、docs/process.md
- 上面的设计依据
- `workbench/js/core/rooms2.js`（`validate`、`variant`）、`tools/check-rooms2.mjs`
- `content/catalog/slices.json`、`worlds.json`、`recipients.json`、`cargo.json`、`monsters.json` 的 jeju 条目

## 可改的文件
- 新建：`content/rooms/jeju/*.json`
- `content/i18n-rooms2/en.json`、`zh-Hans.json`（只加 jeju 的键）
- `content/catalog/slices.json`（只动 `jeju_1`、`planned` 和 `delivery_pool`）
- `content/catalog/worlds.json`（只给 `jeju_dragonfly` 加 `fed`，见第 4 条）
- `docs/design/delivery-jeju.md`（状态、第 4 节"和设计不同的地方"）、`docs/design/delivery-puzzle-rules.md`（只改第 6 节地图表和统计）
- 生成文件：`content/rooms2-check.generated.json`、`workbench/js/core/font-rooms2.js`、`content/export/*`。用工具重新生成后提交，不手改

## 不能碰的文件
- AGENTS.md 2a 的冻结区：已有的美术源文件和确认记录、`workbench/js/core/` 的绘制文件、`content/i18n/*.json`
- 石牢、地府的房间和设计；`rooms2.js`、`mapgen2.js`、`tilemodel*.js`、`mech/*.js`（规则不够用就在交付里写，不自己改）
- `docs/status.md`、`game/**`

## 验收标准
- process.md 第 6 节的全套检查。
- `node tools/check-rooms2.mjs --write` → 0 失败；13 间 jeju 房间每种翻转 × 每条路线都通过；开局池 300 个种子 `dungeon_2`、`diyu_1`、`jeju_1` 都抽到并且都能生成。
- `node tools/content.mjs check` → 0 错误。
- 工作台：配送 v2 里选济州玩一局，顶边是天空、两边是石墙；提示动物是小马和蜻蜓；按 `H` 喂零食有提示气泡。

## 交付（制作方填写）
- 分支名、最后提交号、交回方式（推送 / bundle 文件名）
- 验收命令的实际结果
- `git diff --stat origin/claude/inspiring-ride-zfnn4s..dlv/DLV-04`
- 改了哪条测试的预期、为什么
- 问题：拿不准、需要用户决定的事
