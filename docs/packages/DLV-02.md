# DLV-02 配送 v2 在 Godot 里实现

状态：配送 v2 线 · 待做（需要 DLV-01、UI-07 完成，**用户已确认 v2 美术**；用户说过配送的实现暂时不做，等用户安排）
设计依据：[delivery-puzzle-rules.md](../design/delivery-puzzle-rules.md)；[architecture.md](../design/architecture.md)（`modes/delivery/`）；DLV-01 写进规则文档的实时一节

## 目标
Godot 里能玩一局 v2：开局三滚轮 → 按种子生成地图 → v2 房间（1×1–2×2 屏、浮块、撑篙、跟随镜头、Tab 看全图、画面外怪物箭头）→ 提示动物三级提示、驿站买零食 → 送达结算；每个数字和工作台一致。

## 要读的文件
- AGENTS.md；`docs/design/delivery-puzzle-rules.md`、`delivery-realtime.md`、`architecture.md`、`ids.md`；DLV-01、UI-07 的「交付」
- `workbench/js/core/rooms2.js`、`mapgen2.js`、`realtime2.js`（DLV-01）、`delivery-scene2.js`（画法参考）
- `content/export/*`、`art/export/manifest.json`（只用 `current_is_approved` 为 true 的资产）

## 要产出或修改的文件
- **先验证**：SDK 能直接开 40 × 20 格（2×2 屏）的世界；记录 1×1、2×1、1×2、2×2 房间的帧耗时，写进交付。开不了或太慢就先停下，在交付里写清楚，回到规则文档改房间大小的上限
- `game/modes/delivery/` 下的 v2：读 `pushbox.room/2`、翻转与封口、浮块（会移动的静态块，每移动一格重建这几格的碰撞，把上面的人和箱子一起平移）、撑篙、镜头（`CAM` 的数字逐个照抄，整数像素）、提示动物（`nextHint` 与 `done` 谓词、主 / 飞分工、零食）、开局池（`reels` / `layout` 取随机数的顺序逐个一致，`picks` 重转）
- 对照表：先给 `tools/check-rooms2.mjs` 加 `--golden`，写 `content/export/delivery2-golden.json`（前 30 个种子的整张地图，以及每间房每种摆法的最短解步数），Godot 的 headless 测试逐项对照
- 镜头对照：抽 3 间多屏房间各跑 600 刻，镜头位置序列与 `cameraStep` 一致

## 不能碰的文件
- AGENTS.md 2a 的冻结区；`art/**`；关卡模式；v1 配送切片（`dungeon_1`）的规格和对照表

## 验收标准
- 命令：多屏房间的 SDK 世界验证结果（能不能开、帧耗时）写进交付；Godot 测试全部通过；`delivery2-golden.json` 30 个种子逐项一致；每间房的作者解 / 演示在 Godot 回放的刻数和终点状态与工作台相同
- 画面：每间房截一张图，与工作台的房间画面对照（允许已知差异，写清楚）；没有使用任何未确认的美术（发布构建检查通过）

## 交付（制作方填写）