# 资产清单（按 GD-2 设计）

每件资产的当前版本与确认状态以工作台「确认」页和 `art/export/manifest.json` 为准；本表只说明**需要什么**、**为什么**，以及旧资产的去向。

## 1 已有候选（v1，待用户确认）

| 资产 | 用途 | 章 |
|---|---|---|
| `char.miner` | 主角 21 帧：待机、走、推、爬、挖、倒、落、胜利 | 全部 |
| `obj.crate_wood` / `obj.crate_iron` | 木箱 / 铁箱 | 1 / 2 |
| `mech.door`、`mech.plate`、`mech.link_symbol` | 门（开关动画）、压板、配对符号（圆、三角、方） | 1 |
| `mech.socket`、`mech.socket_lit`、`mech.exit_flag`、`mech.ladder` | 箱子槽、点亮叠加、出口旗、梯子 | 1 |
| `item.sandbag`、`item.bomb` | 背包图标 | 1 / 3 |
| `fx.land_dust`、`fx.dig_bits`、`fx.goal_spark` | 落地、挖土、点亮 | 1 |
| `theme.*`（6 个） | 地形图案、背景、生态清单：石牢、神庙、晶窟、古森、圣域、星站 | 1–5 + 扩展 |
| `fauna.*`（9 个）、`deco.*`（10 个） | 各主题的小动物与植物：蝙蝠、老鼠、苔藓、火把；金甲虫、垂藤、金莲；飞蛾、荧光蘑菇、紫晶；知更鸟、蝴蝶、野花、草丛；白鸽、云灵、雏菊；无人机、异星球芽 | 对应主题 |
| `ui.icons`、`ui.goal_lamp`、`ui.keycap`、`ui.panel`、`ui.cursor`、`ui.target`、`ui.class_icon` | 界面元素、目标高亮、观察模式图标 | 全部 |
| `ui.screen.lobby` / `chapters` / `levels` / `pause` / `hint` / `complete` / `settings` / `rulecard` | 界面布局参考 | 全部 |

第一个可玩闭环（第 1 章 + 菜单）需要的资产，以上已经全部覆盖。

## 2 尚未制作（按章节动工前补齐）

| 资产 | 章 | 说明 |
|---|---|---|
| `mech.lift`、`mech.bin`（含刻度帧）、`fx.splash`、木箱浮动帧 | 2 | 升降台、收集斗、入水水花 |
| `terrain.quarry`、`fx.explosion`、裂岩崩落碎块、碎石与引信的着色规则 | 3 | 爆破章 |
| `terrain.grove`、酸液 / 软岩 / 轻烟 / 沉雾 / 菌塞的着色规则、`mech.vine`（生长帧） | 4 | 苔林章 |
| `terrain.forge`、木栅 / 火 / 冰的着色规则、`mech.torch`、`mech.frost_vent` / `mech.heat_vent`、`fx.fire` | 5 | 熔窟章 |
| 放置炸药的人物动作（可复用"倒"的姿势） | 3 | 视试玩反馈决定 |
| 音效与音乐 | — | 不在本轮美术范围内 |

## 3 旧 42 项的处理（快照 `0fae58c` 中的 `tools/art-lab/js/data/assets.js`）

| 旧资产 | 决定 | 理由 |
|---|---|---|
| `miner_idle`、`miner_walk`、`miner_dig`、`miner_pour`、`miner_climb` | **重画并合并**为 `char.miner` | 补齐推、落、胜利动作；统一一张图集和动画表；加入背后的沙袋，作为角色辨识点 |
| `crate_wood_dungeon` / `_forest` / `_ruins` | **合并**为 `obj.crate_wood` | 同一种规则的物体在各章保持同一外观，玩家不用重新辨认 |
| `crate_iron_all` | **重画**为 `obj.crate_iron` | 冷灰色带铆钉，与木箱形成材质对比 |
| `icon_bomb`、`icon_sandbag`（0–7 满度） | **重画**为 `item.bomb`、`item.sandbag`（满 / 空） | 背包按"袋"计数，1 袋 = 1 格，不再显示满度 |
| `vine_ladder` | **保留概念**，第 4 章重画为 `mech.vine` | 游戏层机关仍在设计中 |
| `ruins_brazier` | **改为**第 5 章 `mech.torch` | 火盆变成可操作的点火开关 |
| `ui_keycaps` | **重画**为 `ui.keycap` | 方向键与字母键；Shift、Ctrl、Esc 等宽键由九宫格加文字绘制 |
| `ui_lobby_screen`、`ui_campaign_screen` | **重做**为 `ui.screen.*` | 新的章节、关卡结构 |
| `tile_forest_grass`、`tile_sky_marble`、`tile_cosmos_hull`、`tile_cave_sulfur` | **改为**程序化 `theme.*` 的地形图案（草皮、白石镶金、舱板警示条、粗糙岩洞） | 地形由着色器逐像素绘制，不用贴图 |
| `forest_bird`、`forest_butterfly`、`sky_dove`、`cloud_sprite`、`ruins_scarab`、`cave_moth`、`cosmos_drone`、`dungeon_bat` | **恢复并重画**（2026-10-15 用户决定） | 按美术规范第 6 节的生态规则重画为 `fauna.*`；`forest_frog` 暂不做，以免与水面玩法混淆 |
| `hazard_gargoyle`、`hazard_mole` | **删除** | 挑战模式移出规划 |
| `flower_sway`、`mushroom_glow` | **恢复并重画**为 `deco.forest_flower`、`deco.cave_mushroom` | 同上 |
| `wind_pinwheel`、`cloud_pad`、`cosmos_teleporter` | **删除** | 它们是机关而不是装饰，对应机制已移出主线 |
| `map_*`（6 张旧地图） | **删除**地图布局，主题风格由 `theme.*` 继承 | 旧关卡布局不再使用 |
