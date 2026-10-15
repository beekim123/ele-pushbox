# SDK v1.2 设计相关事实（逐条核对源码）

SDK：ele-base-cpp v1.2.0，提交 `dacb93e6dc898ac8d1dfa95f6bc15686a183cf18`；Godot 适配层随同一提交。核对日期：2026-10-15。核对方式：阅读源码与官方集成文档，本轮**没有**编译或运行 SDK。下表的"出处"均为 SDK 仓库内的路径；"影响"列是本项目的设计结论。

完整接口与参数表仍以 SDK 仓库的 `sdk/INTEGRATION.md`、`api/godot-1.2.txt` 为准；本文件只记录影响玩法与工程决策的部分。旧版 `sdk-capability-map.md`（快照 `0fae58c`）大部分内容正确，下文"更正与补充"一节列出它遗漏或说得不准的地方。

## 1 Godot 接口边界

| 事实 | 出处 | 影响 |
|---|---|---|
| Godot 可调用的方法见 `api/godot-1.2.txt`。没有读取粒子列表的公开方法；`debug_particles` 只在 `DEBUG_ENABLED` 构建中绑定 | `adapters/godot/src/ele_world.cpp` 第 62–63、180–186 行 | 粒子玩法只能在固定阶段之后数沉积量，正式包里不能读飞行中的粒子 |
| `get_stats()` 只返回 tick、`active_chunks`、`queue_size`、命令计数、`pressure_moves`、`electric_heads`、`bodies` 以及渲染计数；不返回 thermal 的 awake 数 | `ele_world.cpp` 第 457–467 行 | 温度传导期间 `active_chunks` 可能为 0，无法判断是否已静止 → 涉及温度的装置一律采用固定阶段 |
| 读取：`get_material_ids`、`count_materials`、`get_cell`（含 burning 和 reg）、`layer_value`（逐格）、`query_component`、`get_body_info` | `api/godot-1.2.txt` | 格子分类用 `get_material_ids` 一次读全图；收集斗用 `count_materials` |
| 事件只有 `exploded`、`body_created`、`body_destroyed`、`command_rejected`、`stepped`、`region_*` | 同上 | 反应、点燃、相变、寿命到期都没有事件，只能轮询 |

## 2 写入与状态保留

| 事实 | 出处 | 影响 |
|---|---|---|
| `set_cell` / `paint_rect` / `paint_circle` / `fill_noise` 用 `make_cell` 新建格：重新生成随机颜色位，`reg` 重置为新的寿命（无寿命时为 0），不带 BURNING 标志 | `src/core/cell.cpp` 第 3–15 行；`src/core/world.cpp` 第 241–258 行 | 推、挖、倒都会丢失燃烧和寿命状态 |
| 写入新格时，只有材料定义了 `spawn_temp` 才写温度 layer；否则该位置保留原有温度，温度不会跟着材料走 | `src/core/cell_write.hpp` | 搬运不能保留温度 → 禁止搬运高温、燃烧、带寿命的材料（设计 3.4） |
| 写 layer（`set_layer_value`、`paint_layer_circle`）会给 chunk 置上依赖该 layer 的求解器唤醒位 | `src/core/world.cpp` 第 206–224 行 | 火盆、冷凝喷口画一次 layer 即可在下一 tick 生效 |
| 画笔模式 1–3 逐格过滤（只写空格、空或流体、非 static），默认模式 0 会覆盖 static 和刚体 | `sdk/INTEGRATION.md` [F230] | 倒沙使用模式 2（空或流体），避免覆盖箱子 |

## 3 求解器行为

| 事实 | 出处 | 影响 |
|---|---|---|
| 粉末：直落，或与正下方更轻的液体交换，否则斜落；没有横向输送，没有休止角参数 | 旧能力表 2.1（实测）；`src/solvers/cells/` | 开阔地面上的一格沙会摊成坡 → 新增夯土（static）作为可挖墙体；倒沙落点要有约束 |
| `move_chance` 只降低平均移动速度，慢速格会让所在 chunk 保持活动 | `cell_solver.cpp` 第 239 行 | 碎石结算会自然等它停下，不需要玩家掐时机 |
| 寿命 1..255 tick，到期转为 `to` 材料，与 `burnable`、`conductor` 互斥 | `cell_solver.cpp` 第 133–136 行；`content.cpp` | 菌塞最长约 4.25 秒，结算期间完成 |
| 爆炸破坏判定只看距离和抗爆性，不做遮挡；没被摧毁且在半径一半以内（`4·d² ≤ r²`）的可燃格会被点燃 | `src/solvers/explosions/explosions.cpp` 第 64 行 | Q02「隔墙也会炸」、F04「炸药也点火」直接来自源码事实 |
| thermal 用自己的唤醒位（bit 1）持续处理温度变化，不进入 `active_chunks` | `src/solvers/thermal/thermal.cpp` 第 25、50–52、188、198 行 | 同第 1 节：温度类装置使用固定阶段 |
| electric：有电源或电子在动时，chunk 一直保持唤醒 | `src/solvers/electric/electric.cpp` 第 94–126 行 | 有电源的关卡永远无法静止 → 电路放入扩展章，并采用固定阶段 |
| 耦合器参数 `stride` 默认 4，取值 1..64 | `src/core/registry.cpp` 第 55 行；`couplers.cpp` 第 38 行 | 冷凝 / 热喷口要写 `stride: 1` 才能当 tick 生效 |
| air 求解器：压差推动 **gas 格**（`cells.drift_shift`）和**粒子**（`particles.air_push`）；刚体、粉末、液体都不受气压影响 | `INTEGRATION.md` [F15][F216]；引用 air 的源码只有 `air.cpp`、`cell_solver.cpp`、`particles.cpp`、`explosions.cpp` | 旧草案的"气压吹箱 / 云垫"只能是游戏层规则 → 本版移出主线 |
| `liquid_pressure` 只把"上方是空或气体"的最高格搬到最低开口；被 static 盖住的液面不算开口；只在已唤醒的 chunk 中找种子 | 旧能力表 2.7（实测）；`INTEGRATION.md` [F217] | W04 连通器的两侧液面必须敞开；开闸后要唤醒相邻水体（EXT-09 的替代做法：重写水体中的一个 cell） |

## 4 快照、回放、确定性

| 事实 | 出处 | 影响 |
|---|---|---|
| 相同内容、seed 和命令序列，每个 tick 的 `get_state_hash()` 相同，与线程数无关；哈希包含 tick 数 | `INTEGRATION.md` 第 14 节；旧能力表 2.14（实测 1、8 线程一致） | 提示和状态比较只用游戏层局面，不用哈希 |
| 含刚体的世界从快照载入后，之后的模拟与不中断运行**不保证**位级一致；回放内嵌的快照中有刚体时 `verify_replay` 返回 `ERR_UNSUPPORTED`；从无刚体的开局开始、中途创建刚体的回放可以校验 | `INTEGRATION.md` 第 66、695 行 [F32][F174] | 刚体关的撤销只能从开局重放 → 移入扩展章 |
| Godot 侧没有内存快照；`save_snapshot` 写文件（320×192 约 213 KB） | 旧能力表 2.14（实测） | 撤销每步一个快照文件，上限 200 步，约 42 MB |
| 命令在下一次 `step()` 开头执行；随机数包含 tick | 旧能力表第 1 节 | 结算必须在同一 tick 提交同样的命令才能重现结果 |

## 5 更正与补充（相对旧能力表与旧设计草案）

| 旧说法 | 核实结果 | 处理 |
|---|---|---|
| 旧草案 C03、C06、C08：用"降温脉冲"让水真实结冰作为冰桥 | 写低温 layer 能让水当 tick 相变成冰（thermal 的 `phase_down`）；但冰之后慢慢回温，融化发生在以后某次结算中，而温度变化又不进入静止判定 → 玩家会看到"隐藏计时" | 改为耦合器装置冰（无 `phase_up`），由热喷口显式化开 |
| 旧草案 S01、S02："压力脉冲把气体送向标记口" | 技术上可行（游戏层写 `air_pressure`），但压力不可见，玩家难以预测 | 移出主线 |
| 旧草案 S05、S07："云垫托轻箱" | 气压不作用于格子箱子或刚体，只能是纯游戏层规则，与"物理是因果"的定位矛盾 | 删除 |
| 旧能力表 2.5：粒子 Godot 侧读不到 | 正确；补充：`debug_particles` 只在 debug 构建中存在 | 不在正式逻辑中依赖 |
| 旧能力表 2.3："只改温度、不改材料时不唤醒 cell" | 正确；补充：thermal 有自己的唤醒位，会继续计算，只是 Godot 统计看不到 | 固定阶段 |
| 旧 v0.3：箱子搬移"读出 cell 再逐格写回" | 写回的格会重新随机颜色位、重置 reg | 箱子用不可燃、不带寿命的材料；渲染时箱子贴图盖在 SDK 格上方，不依赖 SDK 颜色 |
