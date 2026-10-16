# DLV-01 配送 v2 的实时规则（设计模型）

状态：配送 v2 线 · 待做（用户安排后开工；不需要等美术确认）
设计依据：[delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md) 第 3–5 节；[delivery-realtime.md](../design/delivery-realtime.md)；[delivery-dungeon.md](../design/delivery-dungeon.md)、[delivery-diyu.md](../design/delivery-diyu.md) 第 3 节

## 目标
v2 房间能在 60 刻的实时模型里跑：浮块推 / 撑篙的时序、镜头每刻跟随、提示动物走位，以及游魂、跳跳僵尸、小鬼的移动；每间房至少一段演示输入，`check-rooms2` 回放全部通过，规则和数字写进设计文档。

## 要读的文件
- AGENTS.md；`docs/design/delivery-realtime.md`（刻、移动间隔、下落、怪物、受伤、演示与回放记录）、`delivery-puzzle-rules.md`
- `workbench/js/core/realtime.js`（v1 实时模型）、`rooms2.js`、`mapgen2.js`、`delivery-scene2.js`
- `tools/check-rooms.mjs`（v1 怎么回放演示）、`tools/check-rooms2.mjs`
- `content/rooms/dungeon/dungeon2_*.json`、`content/rooms/diyu/*.json`、`content/catalog/slices.json`（`dungeon_2`、`diyu_1` 的数值）、`monsters.json`

## 要产出或修改的文件
- 新文件 `workbench/js/core/realtime2.js`：在 v1 实时模型外面加 v2 的东西，v1 的行为一点不改。至少定下并实现：
  1. 推浮块用推箱子的间隔（18 刻）、撑篙用挖的间隔（21 刻）；浮块和上面的人、箱子在同一刻移一格，移动动画 0.1 秒；
  2. 镜头每刻 `cameraStep` 一次，进房间 `cameraStart`；
  3. 提示动物按格子寻路走到目标（不穿墙），速度、"走近 3 格"的判定、气泡显示多久；
  4. 游魂：穿墙飘（整数三角波，范围 = legend 的 `zone`），碰到掉心，灯光照到退开；
  5. 跳跳僵尸：每隔几刻朝人直线跳一格；人站着不动（屏息）时看不见人，按原方向跳过去；黄符定住；跳进忘川被冲走；
  6. 小鬼：成群跟着人，捡走地上的东西（可参考 v1 鼠群）；能推，推进忘川被冲走，挖坑困住；
  7. 要拍板的问题写进文档并给默认值：怪物能不能站在浮块上被带走、推浮块会不会把怪物挤开、站在浮块上被带着走算不算"动"（僵尸看不看得见）。
- 房间 JSON 加演示输入（每间至少一段；过道房演示对付怪物），`check-rooms2.mjs` 回放并写进报告（同 v1 的 `demos` / `replays`）。
- `docs/design/delivery-puzzle-rules.md` 新增"实时"一节，写清每个数字；`tests/` 加实时测试（推浮块的刻数、撑篙、僵尸屏息、游魂穿墙）。

## 不能碰的文件
- AGENTS.md 2a 的冻结区；`realtime.js` 的 v1 行为（v1 的对照表 `content/export/delivery-golden.json` 和 v1 回放结果不能变）
- 已确认的美术；`content/i18n/*.json`、`content/i18n-delivery/*.json`
- `content/catalog/**` 只能改 `slices.json` 里 `dungeon_2`、`diyu_1` 的数值，要在交付里写明

## 验收标准
- 命令：`node tools/check-rooms2.mjs --write` → 0 失败，报告里每间房都有回放；`node tools/check-rooms.mjs` → v1 结果与改动前相同；`node tools/content.mjs check` → 0 错误；`node --test tests/*.test.mjs` → 全部通过
- 行为：同一段演示输入跑两次，每一刻的状态完全相同

## 交付（制作方填写）