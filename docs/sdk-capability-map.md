# ele-base-cpp 能力清单（两款游戏共用）

> 版本：v1.2.0，commit `dacb93e6dc898ac8d1dfa95f6bc15686a183cf18`（2026-10-02）。
> 核对来源：`include/ele/**.hpp`、`src/core/content.cpp`、`src/core/commands.cpp`、`src/core/world.cpp`、各求解器源码、`api/godot-1.2.txt`、`adapters/godot/src/ele_world.cpp`、`sdk/INTEGRATION.md`。2026-10-13 审核时逐项复核，并在本机编译 SDK 实测（程序和结果在 `_work/measure/`，文中标“实测”）。
> 用途：写设计时查“SDK 能直接做什么、做不到什么”。做不到的列进 [sdk-extension-requests.md](sdk-extension-requests.md)。

## 1. 硬约束（设计必须遵守）

| 约束 | 值 | 对设计的影响 |
|---|---|---|
| 世界尺寸 | 宽、高都是 64 的倍数且 ≥ 64，宽 × 高 ≤ 16,777,216 | 640×360 不合法。可用 640×384，或 320×192 配 `cell_scale = 2` |
| chunk | 64×64 | 唤醒、版本号、预算都按 chunk 计 |
| tick | 每次 `step()` 推进 1 tick，调参按 60 tick/s | 实时游戏 `auto_step = true`；回合制 `auto_step = false` 后调用 `step(N)` |
| 命令延迟 | 命令在下一次 `step()` 开头按提交顺序执行，然后才跑求解器 | 画完立刻查询会查到旧值 |
| 命令队列 | 每 tick 最多 4096 条，数据合计 ≤ 32 MiB | 关卡初始化要合并成矩形，或分几个 tick 提交 |
| 随机数含 tick | 新 cell 的颜色位和方向位、粉末斜落方向都来自 `rng64(seed, salt, tick, x, y)` | 同一命令晚一个 tick 执行，结果就不同；预演和真实世界必须在同一 tick 提交同样的命令 |
| 求解器 | 固定 13 个，游戏不能注册自己的求解器；一个 profile 最多 16 个 | 推箱、敌人、塔、经济、波次、寻路全在游戏层实现 |
| 游戏状态 | 快照和回放只含世界状态 | 回合数、金币、塔、敌人要游戏自己序列化 |
| 移动速度 | 每 tick 最多 32 格 | — |
| 内容 | 材料 ≤ 4096 种，每种 ≤ 8 个 tag，全局 tag ≤ 64；layer ≤ 8；耦合规则 ≤ 64；只能写整数 | 足够两款 demo 使用 |
| 平台 | macOS arm64 + Godot 4.7.2；位级一致只在同平台同构建内保证 | — |
| 运行中换内容 | 不行，换材料表或反应表要重建世界 | 每关可以有自己的内容文件，但开局后固定 |

游戏侧规则（INTEGRATION.md 第 7 节，摘要）：

- 改世界只走命令（第 1 条）；
- 一个 physics 帧推进 1 tick；
- 影响世界的随机数只能来自 seed；
- 随时间自动发生的规则写进内容 JSON，不写进脚本；
- 用材料名，不用材料 id；
- 游戏自己的状态自己保存（第 9 条）。

## 2. 能力表

### 2.1 元胞与材料（求解器 `cells`）

| 能力 | 怎么用 | 限制 |
|---|---|---|
| 5 类材料：`empty`、`static`、`powder`、`liquid`、`gas` | 材料 JSON `ele.materials/1`；`materials[0]` 必须恰好是 `{"name":"empty","class":"empty"}` | 密度相等的两种材料永远不互换 |
| 下落和流动 | `fall` 0..31（每 tick 最多下落 fall+1 格，只能写在 powder、liquid、gas）、`disp` 0..31（横向，只能写在 liquid、gas） | 见下面三条 |
| 粉末 | 直落；或与正下方更轻的液体交换；否则斜落一格（目标可进入，**且侧面那格是空或流体**） | 没有横向移动，没有休止角参数：沙块旁边是空格就塌成 45° 坡（实测推箱 D2 开局就塌）；平地上的沙不动 |
| 液体 | 直落 → 斜落 → 横流。横流只在 32 格内看到“下面可进入”的落点时才走，每 tick 最多 disp+1 格 | **平地上单层的水不会继续摊开**；离落点超过 32 格的薄水层会留在原地（实测塔防中仓留下约 16 个 cell）。宽液面可能残留台阶（每 33 格最多 1 格高） |
| 慢速移动 | `move_chance` 1..256（单位 1/256） | 只降低平均速度；慢速格会让所在 chunk 持续清醒 |
| 下沉气体 | `sinks: true`（只能用在 gas 上） | 不进入液体 |
| 标签 | `tags`，反应和耦合器里用 `#tag` 匹配 | 反应产物不能写 tag |
| 寿命 | `lifetime {min,max,to}`，1..255 tick；static 材料也可以带 | 最长约 4.25 秒，更长可以两段拼接；和 `burnable`、`conductor` 互斥（都占用 `reg`） |
| 碰撞 | `collide`（只有 static、powder 能设为 true） | — |
| 发光 | `emission` 0..255 | 只影响渲染 |
| 每格数据 | 4 字节：material、reg、flags | **没有留给游戏用的位**，机关状态只能用“两种材料”或自定义 layer 表达 |

### 2.2 反应（`ele.reactions/1`）

- 规则 `{a, b, to_a, to_b, chance}`，五个字段都必填；a、b 可写 `#tag`，自动登记双向；产物写材料名或 `"keep"`。
- 执行时只看 4 邻居，起始方向随机；每格每 tick 最多反应一次。static 与可移动材料的反应由可移动的一方处理。
- **限制**：
  - 与温度无关；
  - 不能写方向（例如只在“上方”时反应）；
  - 不能写三元或多格模板；
  - 刚体像素不参与；
  - 反应不产生事件。

### 2.3 热、相变、燃烧（`thermal` + `temperature` layer）

- 温度单位 1/8 K，默认 2344（293 K）。可用字段：
  - `spawn_temp`、`hold_temp`（恒温热源）；
  - `phase_up`、`phase_down`（相变，到阈值的当 tick 就变）；
  - `conductivity`（0..64）。
- `burnable`：点燃温度、燃烧时长（1..255 tick）、蔓延概率、喷火、烧完的产物。`extinguishes` 只清除燃烧状态，不降温。
- 点燃只有三条途径：温度达到 `ignite_temp`、爆炸、电火花。**没有“直接点燃”命令**，要画火或用 `paint_layer_circle(&"temperature", …)` 升温。
- 传热慢：每条边每 tick 的通量 = `(k × ΔT + 随机 0..511) >> 9`，k ≤ 64，即单边系数 ≤ 1/8；空格按 `relax_shift` 回到环境温度（默认每 tick 1/64），与别的格导热时 k ≤ `air_conductivity`（默认 4）。
- 实测：用降温冻水做冰塔时，施放到 1200（150 K）的冰 60 秒都不化；只降到 2150、冰的导热调到 64，也要 37 秒。几秒级的冻结不适合用温度做（塔防改用耦合器 + 寿命）。
- 只改温度、不改材料时不唤醒 cell，`active_chunks` 不计。

### 2.4 爆炸（`explosions`）

- 两种触发：命令 `explode(x, y, radius 1..64, power 0..65535)`；或材料带 `explosive` 加 `burnable`，烧完即爆，`burn_time` 就是引信长度。
- 破坏判定：`local = power × (r² − d²) / r²`（整数），非空格且 `local > blast_resistance` 时被摧毁。默认抗性：static 2000、powder 200、liquid 50、gas 0。
- 实测 `explode(格中心, 20, 8000)` 对整块材料的摧毁量见推箱模板 2.7：中心格全毁，上下左右毁 66–74%，斜角毁 20–30%。
- 半径一半以内的可燃格会被点燃；有 `temperature` 时按 `heat` 加热；有 `air` 时加压。
- 被摧毁的格按 `debris_chance` 变成碎片粒子；碎片材料由 `debris` 指定。`max_debris: 0` 或 `debris_chance: 0` 都能关掉碎片。
- 连锁：一次摧毁 n 个 explosive 格时，下一 tick 在它们的平均位置产生次级爆炸。每个 chunk 每 tick 最多引爆一个。
- 信号：`exploded(x, y, radius, destroyed)`，不带 power。
- **限制**：爆炸不做遮挡，墙后的格只按距离和抗性判断。要保护某些格，只能靠调高 `blast_resistance`，最大 65535。

### 2.5 粒子（`particles`）

- `spawn_particles(x, y, count, material, speed_q8)`、`spawn_particles_cone(…, angle, spread, life)` 定向喷射、`spawn_particle_list`。
- 总数 ≤ 20000；落地后变回 cell；受 `particles.gravity_q8` 和风（`air_push`）影响。
- **限制**：Godot 侧读不到粒子列表（C++ 有 `ParticlesSolver::view()`）；没有命中或落地事件。不能拿粒子当子弹做命中判定。

### 2.6 刚体（`rigid`，Box2D v3.1.1）

- `create_body_from_rect`（宽、高 ≤ `max_body_size`）、`create_body_from_component`（连通块 ≤ 4096 格）、`apply_impulse`、`destroy_body`（把像素写回网格）。
- 查询：`get_body_at`、`get_body_info`（位置 Q8、角度、速度、像素数）。信号：`body_created`、`body_destroyed`。
- 刚体可以燃烧、落水、被炸飞或炸碎；最多 256 个。profile 中必须排在 `explosions` 之后。
- **限制**：位置连续、不对齐网格；刚体像素不参与反应；带刚体的快照读回后不保证位级一致；内嵌刚体快照的回放无法校验。**网格推箱不能用刚体当箱子。**

### 2.7 液体压力（`liquid_pressure`）

- 连通器：对每片同材料、4 连通的液体，把“上方是空或气体”的最高格搬到“上方是空或气体”的最低格的正上方；高度差 ≥ 2 才搬，所以 U 形管两边液面最终相差 ≤ 1 格。
- 参数：`moves` 1..64（默认 8，每次运行每片液体最多搬几格）、`max_components` 1..64（默认 64）；`rate_divider` 默认 4，可设为 1（每 tick 运行）。
- 没有它时：液面不拉平；宽液面可能残留台阶；休眠的水不会流向远处新开的洞。
- **限制**：
  - 只有搬运，没有流速、流量或水压值可读；
  - **被 static 盖住的液面不算开口**：盖住的一侧不会被“挤高”（推箱 D5 的箱子要靠游戏层的上浮规则抬起）；
  - **只在带唤醒位的 chunk 里找种子**：一片水全部休眠时，旁边新开的洞（例如箱子离开后空出的格）不会被灌满，除非有命令真正改了这片水所在的 chunk。实测推箱 D3 必须“重写一个水 cell”来唤醒，见扩展需求 EXT-09；
  - 每次搬动都会唤醒 cells，所以下一 tick `active_chunks > 0`；`rate_divider` 为 4 时，相邻两次运行之间可能有几个 tick `active_chunks == 0`。

### 2.8 风与气压（`air` + `air_pressure` layer）

- 爆炸加压；压差推动气体格（`cells.drift_shift`）和粒子（`particles.air_push`）。
- `air_pressure` 是 scale 4 的 u16 layer，默认值必须等于 `ambient`（32768）。
- **限制**：没有“风扇”这类持续风源材料，只能由游戏每 tick 写 `air_pressure`。这样做能回放，但也算脚本里的世界规则。

### 2.9 电路（`electric`）

- 按 Wireworld 规则在 `conductor` 材料上传播：头 → 尾 → 导体；8 邻域中恰有 1 或 2 个头时，导体变成头。
- 电源 `power_source {period 2..1024}`；电子头按 `spark_chance` 点燃相邻可燃物。
- **限制**：
  - 导体只能是 static，且不能同时可燃或带寿命；
  - 没有开关、继电器、逻辑门材料；
  - 没有“通电时让某材料变样”的机制（例如通电开门），游戏层要逐 tick 读 `get_cell` 的电状态再画门；
  - **有电源时电子一直在动，每次改电状态都会唤醒 cell，`active_chunks` 永远不为 0**，回合制的“等世界静止”无法结束（扩展需求 EXT-03）。

### 2.10 自定义 layer 与耦合器（`couplers`）

- profile 最多声明 8 个 layer，类型 u8、u16 或 u32，scale 1 或 4。写入用 `set_layer_value`、`paint_layer_circle`（半径 ≤ 1024），读取用 `layer_value`（只能逐格读）。
- 耦合规则最多 64 条，三种：
  - `layer_to_material`：layer 值 ≥ min 时，from（材料名或 `#tag`）变成 to（只能写材料名）；已经是 to 的格和燃烧的格跳过；
  - `material_to_layer`：材料所在格的 layer 值往上加，直到 max；
  - `layer_extinguish`：layer 值 ≥ min 的燃烧格熄灭。
- 写 layer 会给该 chunk 置上耦合器的唤醒位；耦合器在 profile 中排在后面时，**命令执行的同一 tick** 就生效（实测：塔防的全图排水 1 tick 完成；冰塔“画一 tick 的 frost 层”就把圈内的水全部变成冰）。
- 用途：泉眼、毒气源、水深灭火、排水、冰冻、“浓度超标时草枯死”这类数值触发。
- **限制**：
  - 求解器参数 `stride` **不写时默认 4**（每 4 tick 才访问一次 chunk），要当 tick 生效就写 1；用 `layer_extinguish` 做防火带时 `stride` 必须为 1；
  - layer 不会自己扩散（只有 `surface_water`、`gas_field` 会，而它们是俯视用的）；
  - 条件只有“≥ min”；耦合器不能读材料周围的邻居。

### 2.11 俯视专用（两款横版游戏基本不用）

`surface_water`（水深场）、`gas_field`（气体浓度场）、`regions`（墙隔开的房间编号）。横版里的水用 liquid cell 表示。

### 2.12 查询

| 方法 | 返回 | 备注 |
|---|---|---|
| `get_material_at`、`get_material_id_at`、`get_cell` | 单格 | `get_cell` 含 `burning` 和电状态（`reg`） |
| `get_material_ids(x, y, w, h)` | 按行展开的材料 id | 每次 ≤ 65536 格；64×64 约 10 µs |
| `count_materials(x, y, w, h)` | 各材料计数，长度 n+1，末项是世界外的格数 | 每次 ≤ 65536 格；判定“目标区里有多少水”的主力 |
| `query_component(x, y, materials, max_cells)` | 4 连通块的格数、外接矩形、是否接地（grounded）、是否截断 | 只接受 static、powder；用于“悬空就坍塌” |
| `get_chunk_version(cx, cy)` | chunk 变化计数 | 游戏层只在版本变化时重新扫描 |
| `get_stats()` | 最后一个 tick 的计数：`active_chunks`、`queue_size`、`pressure_moves`、`electric_heads` 等 | 只反映最后一个 tick：`step(N)` 之后看不到前面 N−1 个 tick；判断静止要逐 tick 检查 |
| `layer_value` | 单格 layer 值 | 没有批量读取 |

没有：寻路、射线、视线、距离场、按 tag 查询、“世界是否已静止”查询。

### 2.13 事件与信号

只有这些：`command_rejected`、`exploded`、`body_created`、`body_destroyed`、`region_*`、`stepped(tick)`。
反应、相变、点燃、寿命到期、“某材料进入某区域”都**没有事件**，只能轮询。

### 2.14 确定性、存档、回放

- 内容、seed、命令序列相同 ⇒ 每个 tick 的 `get_state_hash()` 相同，与线程数无关（实测推箱 D1–D5 在线程 1、8 下 hash 一致）。
- `get_state_hash()` **包含 tick 数**、全部 cell（含随机颜色位）、待执行命令、唤醒状态和各求解器状态。同样的局面只要 tick 数不同 hash 就不同，所以不适合拿来匹配“玩家走到了哪一步”。
- 存读档：`save_snapshot` 和 `load_snapshot` 写读文件，按材料名重新映射 id。`load_snapshot` 要求节点已经 `start()` 过、内容相同；载入后如果 `recording` 为真，录制从载入处重新开始。实测快照：320×192 约 213 KB，640×384 约 630 KB（颜色位是随机的，RLE 几乎压不动）。
- 回放：`recording`、`save_replay`、`verify_replay`，Godot 侧每 60 tick 一个检查点。
- 自动化测试：场景文件 `load_scenario`（`ele.scenario/1`），原生和 Godot headless 得到同样的 hash。
- **限制**：
  - Godot 侧没有内存快照，也没有 `clone()`（C++ 有 `World::clone`，实测 640×384 约 0.5–1.1 ms）。撤销只能存文件，或从头重放命令。
  - 没有回放播放器，只能校验。

### 2.15 渲染与碰撞

- 渲染：调色板着色器；颜色由 `VARIANT % 颜色数` 选取；`overlay_mode` 1 温度、2 水深、3 气体——水深和气体指俯视用的 `water_depth`、`gas` layer，横版的液体 cell 不会显示在 overlay 2 里；可以换成自己的 shader（`render_shader_path`）。
- 碰撞：`contours` 由可碰撞格生成线段，`CharacterBody2D` 可以直接在上面走；只在 `focus_node` 周围生成。

## 3. 两款游戏的用法速查

| 需求 | 推箱子 | 塔防 |
|---|---|---|
| 推进方式 | 回合制：每个动作后逐 tick `step(1)`，连续 4 tick `active_chunks == 0` 且 `queue_size == 0` 才算静止 | 清晨暂停；守波时每个 physics 帧 `step(1)` |
| 箱子 / 塔本体 | 游戏层实体，在网格上画 static 材料 `crate` 占位；移动时把新位置的 cell 换到旧位置，再唤醒相邻水体 | 游戏层实体，不画进网格（塔位是顶棚上的空凹槽） |
| 地形材料 | 基岩、裂岩、沙、水、闸门 | 基岩、裂岩、泥沙、水、冰（两段寿命）、闸门、核心、尾渠 |
| 判定 | `get_material_ids` 读全图，按格分类 | `count_materials` 数各区域的水量；`get_material_ids` 读敌路通道 |
| 撤销 / 重来 | 每步存快照文件 | 每波清晨存检查点 |
| 爆破 | `explode` + `blast_resistance` 保护基岩和箱子；裂岩剩不到一半整格崩落 | 炸开下路的岩脊改变溢流方向 |
| 冰 | 不用（扩充方向） | `frost` layer 画一 tick + 耦合器把水变冰，冰靠寿命化回水 |
| 敌人 | 无 | 游戏层实体；读材料决定地面、水深、冻结 |

## 4. 做不到的事（扩展需求候选）

下面是设计中可能用到、v1.2.0 不支持的能力。两份 demo-template 用到哪条，就在 [sdk-extension-requests.md](sdk-extension-requests.md) 里正式编号；2026-10-13 审核后的去向写在括号里。

1. **方向性反应**：只在某个方向相邻时才反应（例如“水在上方时种子长草”）。（暂不提）
2. **区域事件**：某材料进入或离开指定矩形时发信号（压力板、目标区），现在只能轮询。（暂不提）
3. **温度条件反应**：反应带温度区间。（暂不提）
4. **通电状态驱动材料变化**：导体通电时邻近的门打开。（原 EXT-07，已撤销：游戏层逐 tick 读电状态即可）
5. **持续风源**：材料像泉眼一样持续给 `air_pressure` 加值。（暂不提）
6. **整块平移或交换命令**：把一个矩形内的格整体搬到新位置，并保留温度和燃烧状态。（原 EXT-01，已撤销：demo 用逐格写回，守恒）
7. **Godot 侧内存快照或 clone**：撤销和提示推演不用写文件。（原 EXT-02，已撤销：文件快照够用）
8. **粒子命中查询或事件**：粒子当子弹时判断命中。（暂不提）
9. **液体流量读数**：某个截面每 tick 流过多少液体。（EXT-06，扩充内容）
10. **超过 255 tick 的寿命或计时**。（暂不提：两段寿命拼接）
11. **按材料白名单或 tag 过滤的画笔模式**。（原 EXT-04，已撤销）
12. **批量读取 layer**。（暂不提）
13. **静止查询**：判断“再推进一 tick 会不会有变化”，并能排除电路等周期性活动。（EXT-03，扩充内容）
14. **唤醒命令**：不改 cell，让休眠的水体重新检查新开的洞。（EXT-09）

写需求的格式按 SDK 自己的规定（INTEGRATION.md 第 10.2 节），包括效果和最小场景、现有能力为什么不够、期望接口、确定性、性能、存档回放和兼容性。新机制只能以可选求解器、新命令或新材料字段的形式加入，取默认值时不能改变已有内容的结果。
